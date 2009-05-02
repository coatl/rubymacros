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
require "macro"
class Macro
  # The syntax node for forms
  class FormNode < RedParse::ValueNode
    param_names :text

    # Create a new form node.  The user should normally not call this
    # function.  Form nodes are created by the parser.
    #
    # +colon+:: A colon token
    # +text+::  A ParenedNode or VarLikeNode
    #
    def initialize(colon,text)
      # Certain node types need to be quoted
      if RedParse::VarLikeNode===text 
        @transform=HashLiteralNode[]
        super text
        return
      end

      # Sanity check - make sure this is a valid ParenedNode
      fail unless ParenedNode===text && text.size==1 
      text=text.body

      super text
      rebuild_transform
    end

    # Initialize the transform and create all the form escapes that are
    # used in this form
    def rebuild_transform
      # TODO: this method needs to be better documented/refactored
      @transform=HashLiteralNode[]
      @parameters=[]

      walkers=proc{|rcvr,wraplayers| #curry
        rcvr.walk{|*args| 
         node=args.last
         case node
         when FormParameterNode
           target=node.wraplevel
           fail if wraplayers > target
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
        escd=escd.val while FormParameterNode===escd
        @transform.push LiteralNode[orig_escd.__id__], escd
      }    

      return self
    end

    # Iterate over all the parameters in this form
    #
    # +block+:: the block to call for each parameter
    #
    def each_parameter(&block)
      @parameters.each(&block) if @parameters
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
    def unparse o
      ":("+text.unparse(o)+")"
    end

    # Called when the form is evaluated to ensure that the abstract form
    # in the parse tree is a concrete form that can be modified (makes a
    # copy of the form).
    #
    # +transform+:: the transform to use in the deep copy
    #
    def reify transform
      transform.each_pair{|k,v|
        transform[k]=Macro.quote(v) unless Node===v or VarNameToken===v
      }
      deep_copy(transform)
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
      # TODO: either split this into mulitple lines or multiple methods
      # possibly formname() should return the ConstantNode portion of
      # the below expression (so that we have one "name" for the form
      # instead of two representations of the same name)
      CallSiteNode[CallSiteNode[ConstantNode[nil,"Macro","Names",formname], "reify", [@transform],nil,nil], "text", nil,nil,nil]
      #:(::Macro::Names::^(formname).reify.text)
    end
    
    # Lazily evaluate the name of the form and return it
    def formname
      @formname ||= ::Macro::Names.request(self)
    end
  end


  # The syntax node for a form escape
  class FormParameterNode < RedParse::ValueNode
    param_names :val

    # Called by the parser to create a new form parameter node.
    #
    # +args+:: TODO
    #
    def initialize(*args)
      super(args.last)    
    end

    # Performs the reverse of a parse operation (turns the node into a
    # string)
    #
    # +o+:: a list of options for unparse
    #
    def unparse o
      "^"+val.unparse(o)      
    end

    # The number of carats (^) that occur in the escape.  Note that
    # this method is recursive.
    def wraplevel
      return val.wraplevel+1 if FormParameterNode===val
      return 1
    end

    def inspect
      val.unparse({})
    end
  end
end