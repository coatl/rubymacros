=begin
    rubymacros - a macro preprocessor for ruby
    Copyright (C) 2008  Caleb Clausen

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

#warn '$LOAD_PATH hacked up to include latest redparse'
#$: << "../redparse/lib"

require "redparse"
#require "macro"
class Macro
  # The syntax node for forms
  class FormNode < RedParse::ValueNode
    param_names :text
    alias val text
    alias body text

    # Create a new form node.  The user should normally not call this
    # function.  Form nodes are created by the parser.
    #
    # +colon+:: A colon token
    # +text+::  A ParenedNode or VarLikeNode
    #
    def initialize(colon,text)
      @startline=@endline=nil

      # Certain node types need to be quoted
      # (or rather, not unquoted)
      if RedParse::VarLikeNode===text
        #this code is dead now, I believe
        @transform=HashLiteralNode[]
        @stars_transform=HashLiteralNode[]
        text.startline=text.endline=0
        super text
        return
      end


      # Sanity check - make sure this is a valid ParenedNode
      if ParenedNode===text && text.size==1 
        text=text.body #unquote the form
      elsif text.size==0
        @transform=HashLiteralNode[]
        @stars_transform=HashLiteralNode[]
        super SequenceNode[]
        return
      end

      super text
      rebuild_transform
    end

    def noinspect_instance_variables
      %w[@stars_transform @transform]
    end

    def initialize_copy other
      replace other
      other.instance_variables{|v|
        instance_variable_set v, other.instance_variable_get(v)
      }
      rebuild_transform
    end

    def _dump depth
      Marshal.dump text,depth
    end

    def self._load str
      result=allocate
      result.replace [Marshal.load(str)]
      result.rebuild_transform
    end

=begin fake _dump/_load, for testing purposes
    def _dump depth
      "foobarbaz"
    end

    def self._load str
      result=allocate
    end
=end

    def initialize_ivars
      rebuild_transform
      super
    end

    # Initialize the transform and create all the form escapes that are
    # used in this form
    def rebuild_transform
      # TODO: this method needs to be better documented/refactored
      @transform=HashLiteralNode[]
      @stars_transform=HashLiteralNode[]
      @parameters=[]
      @parameters.extend RedParse::ListInNode

      walkers=proc{|rcvr,wraplayers| #curry
        rcvr.walk{|parent,i,j,node| 
         node.startline=node.endline=0 if node.respond_to? :startline
         case node
         when FormEscapeNode
           target=node.wraplevel
           #fail if wraplayers > target
           if wraplayers==target #skip this parameter if it doesn't have enough wrappers
             @parameters << node #remember parameter (and implicitly, location)

             nil# and stop further recursion
           else 
             true
           end
         when FormNode
           #walk form with same walker we're using now, except an extra layer of form parameters
           #must be present for them to be considered 'our' parameters
           walkers[node.text,wraplayers+1]
           nil #don't recurse in this node again, we just did it
         else true
         end
        } if rcvr.respond_to? :walk
      }
      walkers[text,1]

      @parameters.each{|orig_escd| 
        escd=orig_escd
        escd=escd.val while FormEscapeNode===escd
        if UnaryStarNode===escd
          @stars_transform.push LiteralNode[orig_escd.__id__], escd.val
        else
          @transform.push LiteralNode[orig_escd.__id__], escd
        end
      }

      return self
    end

    # Iterate over all the parameters in this form
    #
    # +block+:: the block to call for each parameter
    #
    def each_parameter(&block)
      @parameters.each(&block) if defined? @parameters
    end

    # Make a deep copy of this form
    #
    # +transform+:: TODO
    #
    def deep_copy transform={}
      super(transform).rebuild_transform
    end

    # Performs the reverse of a parse operation (turns the node into a
    # string)
    #
    # +o+:: a list of options for unparse
    #
    def unparse o=default_unparse_options
      ":("+text.unparse(o)+")"
    end

    # Called when the form is evaluated to convert the abstract form
    # of the parse tree into a concrete form that can be modified (makes a
    # copy of the form).
    #
    # +transform+:: the transform to use in the deep copy
    #
    def reify transform, stars_transform
      transform&&=transform.dup
      stars_transform&&=stars_transform.dup
      transform.each_pair{|k,v|
        case v
        when Node; next
        when Symbol; v=CallNode[nil,v.to_s]
        else v=Macro.quote v
        end
        transform[k]=v
      }
      stars_transform.each_pair{|k,v|
        case v
        when Symbol; v=CallNode[nil,v.to_s]
        else v=Macro.quote v
        end
        stars_transform[k]=v.extend InlineList
      }
      result=deep_copy(transform.merge( stars_transform ))
      #expand InlineLists somehow
      result.walk{|parent,i,j,node|
        if InlineList===node
          if j
            parent[i][j,1]=*node
          else
            parent[i,1]=*node
          end
          nil #halt further recursion
        else
          true
        end
      } unless stars_transform.empty?
      
      return result
    end

    module InlineList
    end

    # Transform this node into a ParseTree parse tree
    def parsetree
      parses_like.parsetree
    end



    module ::Macro::Names
      COUNT=[0]

      # Sets up the mapping from a form name to a form literal
      #
      # +form+:: the name of the form
      #
      def self.request form 
        result="Number_#{COUNT[0]+=1}"
        const_set result, form
        return result
      end
    end

    #CallSiteNode=RedParse::CallSiteNode
    #ConstantNode=RedParse::ConstantNode

    # Turn the form into something that is legal ruby (since :(..) is
    # not legal ruby syntax).  Thus the form is changed from the syntax:
    #
    #   :(code)
    #
    # to:
    #
    #   RedParse::SomeNodeType[ some transform of code ]
    #
    def parses_like
      startline=@startline if defined? @startline
      endline=@endline if defined? @endline
      ivars={:@startline=>startline, :@endline=>endline}
      CallSiteNode[
        CallSiteNode[formname, "reify", [@transform,@stars_transform], ivars], 
        "text", ivars
      ]
      #:(^(formname).reify(^@transform,^@stars_transform).text)
    end
    
    # Lazily evaluate the name of the form and return it
    def formname
      startline=@startline if defined? @startline
      endline=@endline if defined? @endline
      ivars={:@startline=>startline, :@endline=>endline}

      @formname ||= ConstantNode[nil,"Macro","Names",::Macro::Names.request(self), ivars]
    end
  end


  # The syntax node for a form escape
  class FormEscapeNode < RedParse::ValueNode
    param_names :val
    alias body val

=begin not needed now?
    def initialize(*args)
      super(args.last)    
    end
=end
    # Called by the parser to create a new form parameter node.
    #
    # +args+:: the ^ token (unused), and its argument
    #


    def self.create(*args)
      v=args.last
      case v
      when UndefNode; v=MisparsedNode.new('',v,'')
      when KeywordToken
        case v.ident
        when /\A(?:;|\+>)\z/; v=args[-2]
        when ')'; huh "v foo;(*params) unhandled yet"
        else fail
        end
      end
      new v
    end

    # Performs the reverse of a parse operation (turns the node into a
    # string)
    #
    # +o+:: a list of options for unparse
    #
    def unparse o=default_unparse_options
      "^"+val.unparse(o)      
    end

    def lhs_unparse o=default_unparse_options
      "(^"+val.unparse(o)+")"
    end

    # The number of carats (^) that occur in the escape.  Note that
    # this method is recursive.
    def wraplevel
      return val.wraplevel+1 if FormEscapeNode===val
      return 1
    end
  end
  FormParameterNode=FormEscapeNode
end
