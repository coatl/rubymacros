=begin
    rubymacros - a macro preprocessor for ruby
    Copyright (C) 2008, 2016  Caleb Clausen

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

begin require 'rubygems'
rescue Exception; #do nothing; hope we don't need it
end
require 'redparse'
require "macro/form"
require "macro/node"
require "macro/version"

class Object # :nodoc:
  #as close as I can get to an empty binding (used below in Macro.eval)
  def Object.new_binding() # :nodoc:
    binding 
  end
end

class Macro
  #import Node classes from RedParse
  RedParse::constants.each{|k| 
    n=RedParse::const_get(k)
    self::const_set k,n if Module===n and RedParse::Node>=n
  }
  ListInNode=RedParse::ListInNode #Node helper module
  #...and token classes from RubyLexer
  RubyLexer::constants.each{|k| 
    t=RubyLexer::const_get(k)
    self::const_set k,t if Module===t and RubyLexer::Token>=t
  }

  #all 3 of these are giant memory leaks
  PostponedMethods=[]
  GLOBALS={}
  QuotedStore=[]

  #like Kernel#require, but allows macros (and forms) as well.
  #c extensions (.dll,.so,etc) cannot be loaded via this method.
  #
  # +filename+:: the name of the feature to require
  #
  def Macro.require(filename) 
    filename+='.rb' unless filename[/\.rb\Z/]
    return if $".include? filename 
    $" << filename
    load filename
  end

  #like Kernel#load, but allows macros (and forms) as well.
  #
  # +filename+:: the name of the file to load
  # +wrap+:: whether to wrap the loaded file in an anonymous module
  #
  def Macro.load(filename,wrap=false)
    [''].concat($:).each{|pre|
      pre+="/" unless %r{(\A|/)\Z}===pre
      if File.exist? finally=pre+filename
        tree=File.open(finally){|code|
          #code="::Module.new do\n#{code}\nend\n" if wrap
          Macro.expand(parse(code,finally),filename)
        }

        tree.load filename,wrap
        return true
      end
    }
    raise LoadError, "no such file to load -- "+filename
  end

  def Macro.delete(name,context=::Object)
    Thread.current[:Macro_being_undefined]="macro_"+name
    class<<context; remove_method(Thread.current[:Macro_being_undefined]); end
    if context==::Object
      Macro::GLOBALS.delete name.to_sym
    end
    Thread.current[:Macro_being_undefined]=nil
  end

  def Macro.list(*contexts)
    contexts=[::Object] if contexts.empty?
    contexts.map{|ctx| ctx.singleton_methods.grep(/\Amacro_/) }.flatten.map{|ctx| ctx.to_s.gsub!(/\Amacro_/,'') }
  end

  class ::Module
    def macros
      Macro.list(self)
    end
  end

  def Macro.delete_all!(*contexts)
    contexts=[::Object] if contexts.empty?
    contexts.each{|ctx|
      Macro.list(ctx).each{|mac| Macro.delete mac,ctx }
    }
  end

  #like Kernel#eval, but allows macros (and forms) as well.
  #beware: default for second argument is currently broken.
  #best practice is to pass an explicit binding (see
  #Kernel#binding) for now.
  #
  # +code+:: a string of code to evaluate
  # +binding+:: the binding in which to evaluate the code
  # +file+:: the name of the file this code came from
  # +line+:: the line number this code came from
  #
  def Macro.eval(code,binding=nil,file="(eval)",line=1)
  #binding should default to Binding.of_caller, but byellgch
    
    lvars=binding ? ::Kernel.eval("local_variables()",binding) : []
    code=Macro.parse(code,file,line,lvars) unless Node===code
    tree=Macro.expand(code,file)
    tree.eval binding,file,line
  end

  # A helper for Macro.eval which returns a RedParse tree for the given
  # code string.
  #
  # +code+:: a string of code to evaluate
  # +binding+:: the binding in which to evaluate the code
  # +file+:: the name of the file this code came from
  # +line+:: the line number this code came from
  # +lvars+:: a list of local variables (empty unless called
  # recursively)
  #
  def Macro.parse(code,file="(eval)",line=1,lvars=[])
    if Binding===file or Array===file
      lvars=file
      file="(eval)"
    end
    if Binding===lvars
      lvars=eval "local_variables", lvars
    end
    ::RedParse::WithMacros.new(code,file,line,lvars).parse
  end

  UNCOPYABLE= #Symbol|Numeric|true|false|nil|
             Module|Proc|IO|Method|UnboundMethod|Thread|Continuation

  # Return a quoted node for the given scalar
  #
  # +obj+:: any object or node
  #
  def Macro.quote obj
    #result=
    case obj
      when Symbol,Numeric; LiteralNode[obj]
      when true,false,nil; VarLikeNode[obj.inspect]
      when String
        obj=obj.gsub(/['\\]/){|ch| '\\'+ch }
        StringNode[obj,{:@open=>"'", :@close=>"'"}]

      when Reg::Formula
        Reg::Deferred.defang! obj

      when Reg::Reg
        obj

      # TODO: The following is dead code and should be removed
      else 
        #result=:(::Macro::QuotedStore[^QuotedStore.size])
        result=CallNode[ConstantNode[nil,"Macro","QuotedStore"],"[]",
            [LiteralNode[QuotedStore.size]],
          nil,nil]
        QuotedStore << obj #register obj in quoted store
        UNCOPYABLE===result or
        #result=:(::Macro.copy ^result)
        result=  CallNode[ConstantNode[nil,"Macro"],"copy", 
             [result], nil,nil] 

        result
    end
  end

  # TODO: dead code (only used by the dead else block above).
  def Macro.copy obj,seen={}
    result=seen[obj.__id__] 
    return result if result
    result=
    case obj
      when Symbol,Numeric,true,false,nil; return obj
      when String; seen[obj.__id__]=obj.dup
      when Array 
        seen[obj.__id__]=dup=obj.dup
        dup.map!{|x| copy x,seen}
      when Hash
        result={}
        seen[obj.__id__]=result
        obj.each_pair{|k,v| 
          result[copy( k )]=copy v,seen
        }
        result
      when Module,Proc,IO,Method,
           UnboundMethod,Thread,Continuation
        return obj
      else
        obj.dup
    end
    obj.instance_variables.each{|iv|
      result.instance_variable_set iv, copy(obj.instance_variable_get(iv),seen)
    }  
    return result
  end

  # Create a node to postpone the macro (or method) definition until it
  # is actually executed.  For example, in the following code:
  #
  #   if foo
  #     macro bar
  #       ...
  #     end
  #   else
  #     macro bar
  #       ...
  #     end
  #   end
  #
  # without postponing macro definition, the latter macro would always
  # override the former.
  #
  # +node+::    the RedParse node for the entire method or macro defintion
  #             that is being postponed
  # +session+:: the context in which this macro is being processed
  #
  def Macro.postpone node,session
      return node #disable postponement
=begin was
      filename=session[:filename]
      unless session[:@modpath_unsure]
        modpath=ConstantNode[nil,*session[:@modpath]] 
        modpath.push "Object" unless modpath.size>1
        if session[:@namespace_type]==ModuleNode
          node=ModuleNode[modpath,node,[],nil,nil]    #:(module ^modpath; ^node; end)
        else
          node=ClassNode[modpath,nil,node,[],nil,nil] #:(class ^modpath; ^node; end)
        end 
      end

      evalname=modpath ? "load" : "eval"
      PostponedMethods << node

      #unexpanded=:(::Macro::PostponedMethods[^(PostponedMethods.size-1)].deep_copy)
      #expanded=:(::Macro.expand(^unexpanded,Macro::GLOBALS,{:@expand_in_defs=>true},^filename))
      #return :( ^expanded.^evalname(^filename) )
      unexpanded=CallNode[CallNode[ConstantNode[nil,"Macro", "PostponedMethods"],
                       "[]",[LiteralNode[PostponedMethods.size-1]],nil,nil],"deep_copy",nil,nil,nil]
      expanded=
        CallNode[ConstantNode[nil,"Macro"],"expand",
            [unexpanded,  ConstantNode[nil,"Macro","GLOBALS"], 
             HashLiteralNode[LiteralNode[:@expand_in_defs], VarLikeNode["true"]], Macro.quote(filename)],
          nil,nil]
      return CallNode[expanded,evalname,[Macro.quote( filename )],nil,nil]
=end
  end

  class Node
    #just like Kernel#eval, but allows macros (and forms) and
    #input is a RedParse parse tree (as receiver).
    #beware: default for binding is currently broken.
    #best practice is to pass an explicit binding (see
    #Kernel#binding) for now.
    #
    # +binding+:: the binding in which to evaluate the node
    # +file+::    for purpose of evaluation, the name of the file this node
    #             came from
    # +line+::    for purpose of evaluation, the line number this node came
    #             from
    #
    def eval(binding=nil,file=nil,line=nil)
      #binding should default to Binding.of_caller, but.... that's expensive

      if String===binding
        file=binding
        binding=nil
      end
 
      #references to 'self' (implicit and explicit) within this parse tree
      #should be forced to refer to the self from binding, (if any)...

      expanded_tree=self   #Macro.expand(deep_copy,::Macro::GLOBALS)

      unparsed=expanded_tree.unparse
      #puts unparsed
      ::Kernel.eval unparsed, binding||::Object.new_binding,file||'(eval)',line||1
    end

    # A helper for Macro.load and Macro.eval.  The source code for the
    # node is saved to a file so that it can be viewed in the debugger.
    #
    # +name+:: the name of the file being loaded
    # +wrap+:: whether to wrap the loaded file in an anonymous module
    #
    def load(name='',wrap=false)
      expanded_tree=self    #Macro.expand(deep_copy,::Macro::GLOBALS)

      #replace __FILE__ in tree with the correct file name
      #(otherwise, it will point to some tmp file)
      filenamenode=nil
      expanded_tree.walk{|parent,i,subi,node|
        if VarLikeNode===node and node.ident=="__FILE__"
          filenamenode||=Macro.quote name #StringNode[name.gsub(/['\\]/){|ch| '\\'+ch},{:@open=>"'", :@close=>"'"}]
          if parent
            subi ? parent[i][subi]=filenamenode : parent[i]=filenamenode
          else
            expanded_tree=filenamenode
          end
        end
        true
      }
      
      unparsed=expanded_tree.unparse
      #p expanded_tree
      #puts unparsed
      Tempfile.open("macroexpanded_"+name.gsub("/","__")){|tf|
        tf.write unparsed
        tf.flush
        ::Kernel::load tf.path, wrap
      }
      return true
    end

    # Convert this node to an S-expression
    #
    # +session+:: the context in which this macro is being processed
    #
    def to_sexp session
      # TODO: this (and all other functions similarly named) is possibly
      # dead code
      self.class.name+"["+
        map{|param| call_to_sexp param,session }.join(", ")+
        ", {"+instance_variables.map{|iv| 
                iv=="@data" and next
                val=instance_variable_get(iv)
                val=call_to_sexp(val,session)
                ":"+iv+"=>"+val
              }.join(", ")+"}"+
      "]"
    end

    private
    def call_to_sexp param,session
      if param.instance_of? ::Array 
        "["+param.map{|subparam| call_to_sexp(subparam,session)}.join(", ")+"]"
      elsif param.respond_to?(:to_sexp) 
        param.to_sexp(session) 
      else
        param.inspect
      end
    end
  end

  class ::RubyLexer::VarNameToken
    def to_sexp session
      ident
    end
  end


  #remember macro definitions and expand macros within a parsetree.
  #the first argument must be a parse tree in RedParse format. the
  #optional second argument is a hash of macros to be pre-loaded.
  #(the keys of the hash are symbols and the values are Methods for
  #the corresponding macro method. typically, callers won't need to
  #use any but the first argument; just define macros in the source text.)
  #on returning, the second arg is updated with the macro definitions 
  #seen during expansion.
  def Macro.expand tree,macros=Macro::GLOBALS,session={},filename=nil
    if String===macros
      filename=macros
      macros=Macro::GLOBALS
    end
    if String===session
      filename=session
      session={}
    end
    session[:@modpath]||=[]
    session[:filename]||=filename
    filename||="(eval)"
    case tree
    when String,IO; tree=parse(tree,filename)
    end
    fail unless macros.__id__==Macro::GLOBALS.__id__      #for now
    tree.walk{|parent,i,subi,node|
      is_node=Node===node
      if is_node and node.respond_to? :macro_expand
        newnode,recurse=node.macro_expand(macros,session) 
        #implementations of macro_expand follow, but to summarize:
          #look for macro definitions, save them and remove them from the tree (MacroNode)
          #look for macro invocations, and expand them (CallSiteNode)
          #disable macro definitions within classes and modules(for now) (ClassNode and ModuleNode
          #postpone macro expansion (and definition) in forms until they are evaled (Form)
          #(or returned from a macro)
          #but not in form parameters
          #postpone macro expansion in method defs til method def'n is executed
          #otherwise, disable other macro expansion for now. 
          #postpone macro definitions until the definition is executed.

        if newnode
          return newnode unless parent #replacement at top level
          if subi 
            target,index=parent[i],subi
          else
            target,index=parent,i
          end
          if JustNilNode===newnode and target.class==::Array ||
            case target
            when UndefNode,AssigneeList,SequenceNode; true
            end
            target.delete_at index
          else
            target[index]=newnode
          end
          fail if recurse
        end 
      else
        recurse=is_node
      end
      recurse
    }
    return tree
  end

  #look for macro definitions, save them and convert them to method definitions
  class MacroNode < ValueNode
    def macro_expand(macros,session)
        fail "scoped macros are not allowed (yet)" unless session[:@modpath].empty?

        #varargs, &args and receivers are not allowed in macro definitions (yet)
        fail "macro receivers not supported yet" if receiver
        if args
          last=args
#        else
#          last=args.last
        end
        fail "macro varargs and block not supported yet" if UnOpNode===last and /\A[*&]@\Z/===last.op.ident

        name=self.name
        #macros can't be settors
        fail "macro settors are not allowed" if /=$/===name

        self.args||=[]
        args.unshift VarNode.allocate.replace(["receiver"])
        self.walk{|parent,i,subi,node| #replace self kw in body with receiver var instead
          if VarLikeNode===node and node.ident=="self"
            if subi
              parent[i][subi]=VarNode.allocate.replace(["receiver"])
            else
              parent[i]=VarNode.allocate.replace(["receiver"])
            end
          end
          true
        }

          #macro definitions need to be dealt with in 2 steps: registration and activation
#        name=self.name
        self[1]="macro_"+name unless /^macro_/===name
        node=MethodNode[*self]  #convert macro node to a method def node
        huh(node.receiver) if node.receiver
        node[0]=ParenedNode[ConstantNode[nil,"Object"]] #all macros are global for now... til we get scoped macros
        #sets receiver

        #disable postponement (delayed macros) ... i think they're not necessary
        expand=proc{|x| Node===x ? Macro.expand(x,macros,session) : x}
        node.receiver= expand[node.receiver]
        node.args.map!( &expand )if node.args
        node.body= expand[node.body]
        node.rescues.map!( &expand )if node.rescues
        node.ensure_= expand[node.ensure_]
        node.else_= expand[node.else_]
        node.eval(nil,session[:filename])
        macros[name.to_sym]=::Object.method("macro_"+name)
        return node,false
=begin was
        #node.eval #no, not here....

        newnode=Macro.postpone node, session

        #newnode=:((
        #  ^newnode
        #  Macro::GLOBALS[^name.to_sym]=Object.method ^node.name.to_sym
        #  nil
        #))
        newnode=ParenedNode[SequenceNode[
          newnode, 
          CallNode[ConstantNode[nil,"Macro", "GLOBALS"],"[]=",[
            LiteralNode[name.to_sym], 
            CallNode[ConstantNode[nil,"Object"], "method", 
                 [LiteralNode[node.name.to_sym]],nil,nil]],
           nil,nil],
          VarLikeNode['nil']
        ]]


        #newnode=RedParse::VarLikeNode["nil", {:@value=>false,}]
        #subi ? parent[i][subi]=newnode : parent[i]=newnode          
        return newnode,false #dont keep recursing
=end
    end
  end

  #look for macro invocations, and expand them
  class CallSiteNode
    def macro_expand(macros,session)
      
      name=self.name
      #pp macros
      #pp Macro::GLOBALS
      macro=macros[name.to_sym]
      unless macro
        #turn off modpath surity in blocks.
        #this disables modpath surity in callsite receivers and parameters as well;
        #unnecessary, but no great loss.
        old_unsure=session[:@modpath_unsure]
        session[:@modpath_unsure]=true
        map!{|node| 
          case node
          when Node; Macro.expand node,macros,session
          when Array; node.map{|item| Macro.expand item,macros,session}
          else node
          end
        }
        session[:@modpath_unsure]=old_unsure

        return nil,false #change nothing, recursion done already
      end
      return nil,true unless macro #change nothing but keep recursing if not a macro

      Method===macro or fail

      args = args()||[]

      #if this callsite names a macro, then it is a macro
      #macro=macros[name.to_sym]=::Object.method(macro) if String===macro
      #refuse macro calls with receivers, blocks, varargs, or &args: not supported yet
      fail "macro blocky args not supported yet" if UnOpNode===args.last and args.last.ident=="&@"
      fail "macro varargs calls not supported yet" if UnaryStarNode===args.last
      fail if args.class!=Array
      args.unshift receiver||VarLikeNode.allocate.replace(["self"])
      if block
        newnode=macro.call( *args )do |*bparams|
                  if !blockparams
                    block
                  else
                    bparams=KWCallNode["nil"] if bparams.empty?
                    #warning: scoping rules for lvars in blocks not enforced here
                    #(rather serious violation of variable hygiene)
                    ParenedNode[ AssignNode[MultiAssign[*blockparams],'=',bparams]+block ]
                  end
                end
      else
        newnode=macro.call( *args )
      end
      #subi ? parent[i][subi]=newnode : parent[i]=newnode

      # and keep recursing, no matter what, by all means!!
      if newnode
        newnode=Macro.expand newnode,macros,session #just do it here
        newnode=OneLineParenedNode[newnode] #disable newlines in macro text
      else
        newnode=JustNilNode.new
      end
      return newnode,false                        #and not in caller
    end
  end

  #postpone macro expansion in methods til method defn is executed
  class MethodNode
     def old_macro_expand(macros,session)
       if session[:@expand_in_defs]
         session[:@expand_in_defs]=false
           expand=proc{|x| Node===x ? Macro.expand(x,macros,session) : x}
           self.receiver= expand[receiver]
           args.map!( &expand )if args
           self.body= expand[body]
           rescues.map!( &expand )if rescues
           self.ensure_= expand[ensure_]
           self.else_= expand[else_]
         session[:@expand_in_defs]=true
         return self,false
       else
         return Macro.postpone(self,session),false
       end
     end
     def macro_expand(macros,session)
       expand=proc{|x| Node===x ? Macro.expand(x,macros,session) : x}
       self.receiver= expand[receiver]
       args.map!( &expand )if args
       self.body= expand[body]
       rescues.map!( &expand )if rescues
       self.ensure_= expand[ensure_]
       self.else_= expand[else_]
       return self,false
     end
  end

  #disable macro definitions within classes and modules
  module DisableMacros
     def macro_expand(macros,session)
        old_unsure=session[:@modpath_unsure]
        old_namespace_type=session[:@namespace_type]
        session[:@namespace_type]=self.class
        name=self.name.dup
        if Node===name
          case name.first
          when String; #name contains only constant(s), do nothing
          when nil  #name in an absolute namespace
            name.shift
            old_modpath=session[:@modpath]
            session[:@modpath]=[]
          else      #name in a dynamic namespace
            name.shift
            session[:@modpath_unsure]=true
          end
          unwind=name.size
        else
          unwind=1
        end
        session[:@modpath].push( *name )

        map!{|n| 
            case n
            when nil
            when Node; Macro.expand(n,macros,session)
            when Array; n.map!{|nn| Macro.expand(nn,macros,session) }
            else fail
            end
        }

        if old_modpath
          session[:@modpath]=old_modpath
        else
          unwind.times{ session[:@modpath].pop }
        end
        session[:@namespace_type]=old_namespace_type
        session[:@modpath_unsure]=old_unsure

        return nil,false #halt further recursion: already done
     end
  end
  class ModuleNode; include DisableMacros; end
  class ClassNode; include DisableMacros; end

  class MetaClassNode
     def macro_expand(macros,session)
        old_unsure=session[:@modpath_unsure]
        session[:@modpath_unsure]=true
        map!{|n| 
            case n
            when nil
            when Node; Macro.expand(n,macros,session)
            when Array; n.map!{|nn| Macro.expand(nn,macros,session) }
            else fail
            end
        }
        session[:@modpath_unsure]=old_unsure

        return nil,false #halt further recursion: already done
     end
  end

  #postpone macro expansion (and definition) in forms until they are evaled
  #(or returned from a macro)
  #but not in form parameters
  class FormNode < ValueNode
     def macro_expand(macros,session)
       #return text.to_sexp({})
   

       #maybe this doesn't allow expansion of parameters themselves... only within params?
       each_parameter{|param| Macro.expand(param,macros,session) }


       #replace (text for) form itself with a reference which will be 
       #looked up at runtime (and have parameters expanded at that point too)
       
       


       return parses_like,false #halt further recursion: already done where necessary
     end

     # Convert this node to an S-expression
     #
     # +session+:: the context in which this macro is being processed
     #
     def to_sexp session
       nest=session[:form_nest_level]
       session[:form_nest_level]=nest ? nest+1 : 2

       result=super

       if nest
         session[:form_nest_level]-=1
       else
         session.delete :form_nest_level
       end
       return result
     end
  end

  class FormEscapeNode<ValueNode
     # Convert this node to an S-expression
     #
     # +session+:: the context in which this macro is being processed
     #
     def to_sexp session
       nest=session[:form_nest_level]||1
       carets=0
       node=self
       while FormEscapeNode===node
         node=node.text
         carets+=1
       end
       if carets==nest
         return node.unparse
       else
         return super
       end
     end

     def image
        "^"+body.image
     end
  end

  class MacroNode < ValueNode
    param_names(:defword_,:receiver,:name,:args,:semi_,:body,:rescues,:elses,:ensures,:endword_)
    def initialize(macroword,header,semi,body,rescues,else_,ensure_,endword)
        #decompose header
        if CallSiteNode===header
          receiver=header.receiver
          args=header.args
          header=header.name
        end
        if MethNameToken===header #not needed?
          header=header.ident
        end

        unless String===header
          fail "unrecognized method header: #{header}"
        end
        @data=replace [receiver,header,args,body,rescues,else_,ensure_]

=begin hmm, maybe not a good idea....
        #quote parameters to yield within macro
        walk{|cntr,i,subi,item|
          case item
          when KWCallNode;
            if item.name=="yield" 
              raise ArgumentError if item.block or item.blockparams
              if item.params
                raise ArgumentError if UnAmpNode===item.params.last
                item.params.map!{|param| FormNode.new(nil,ParenedNode[param]) }
              end
              false
            else true
            end
          else true
          end
        }
=end
    end

    alias else_ elses
    alias else elses
    alias ensure_ ensures
    alias ensure ensures

    # Performs the reverse of a parse operation (turns the MacroNode into a
    # string)
    #
    # +o+:: a list of options for unparse
    #
    def unparse o=default_unparse_options
      result="macro "
      result+=receiver.unparse(o)+'.' if receiver
      result+=name
      if args and !args.empty?
        result+="("
        result+=args.map{|arg| arg.unparse o}.join','
        result+=")"
      end
      result+=unparse_nl(body,o)+body.unparse(o) if body
      result+=rescues.map{|resc| resc.unparse o}.to_s if rescues
      result+=unparse_nl(else_,o)+"else "+else_.unparse( o )+"\n" if else_
      result+=unparse_nl(ensure_,o)+"ensure "+ensure_.unparse( o )+"\n" if ensure_
      result+=";end"
      return result
    end
  end

  class OneLineParenedNode < ParenedNode
    #hacky way to get unparser to not emit newlines in most cases
    #I think this isn't necessary now that forms (and subnodes) have their linenums zeroed on creation
    def unparse(o=default_unparse_options)
      old_linenum=o[:linenum]
      o[:linenum]=2**128
      result=super(o)
      diff=o[:linenum]-2**128
      o[:linenum]=old_linenum+diff
      return result
    end
  end

  class JustNilNode<ValueNode
    def unparse(o=default_unparse_options)
      "nil"
    end
  end

  class ::RubyLexer

    module MacroMixin
      #-----------------------------------
      #def FUNCLIKE_KEYWORDS(orig=nil) #was
      #  /(?:#{orig||super}|^v$)/
      #end

      #-----------------------------------
      def rubylexer_modules_init 
        super
        
        @unary_or_binary_chars.add '^'
        @always_binary_chars.remove '^'

      #  @FUNCLIKE_KEYWORDS=FUNCLIKE_KEYWORDS @FUNCLIKE_KEYWORDS unless @FUNCLIKE_KEYWORDS==="v" #was
      end
      #def keyword_v(*args,&block) _keyword_funclike(*args,&block) end #was

      def keyword_macro(*args)
        keywords_def(*args)
      end

      #-----------------------------------
      def method_params?
        lasttok=last_token_maybe_implicit #last_operative_token
        return super unless lasttok
        case lasttok.ident
        when ';'
          if VContext===@parsestack.last
            @parsestack.pop
            true
          #else super  #need this here...? I think not ....
          end
        when ')'
          @moretokens<<KeywordToken.new("<doubled-parens>")
          @parsestack.pop if VContext===@parsestack.last
          true
        when '.'
          true
        else super
        end
      end

      #-----------------------------------
      def keyword_v(str,offset,result)
        result[0]=OperatorToken.new("v",offset)
        @parsestack<<VContext.new(@linenum)
        return result
      end

      #-----------------------------------
      def symbol_or_op(ch) #is this even needed?
        startpos= input_position
        if readahead(2)==":("
          result= OperatorToken.new(read(1), startpos)
          result.unary=true
          return result
        end
        super
      end
 
      #-----------------------------------
      def caret(ch) #match /^=?/ (^ or ^=) (maybe unary ^ too) #is this even needed?
        if @last_token_maybe_implicit&&@last_token_maybe_implicit.ident=='(' or 
          unary_op_expected?(ch)
          result=OperatorToken.new(read(1),input_position)
          result.unary=true
          result
        else
          super
        end
      end

      #-----------------------------------
      def callsite_symbol(x) #is this even needed?
        return if nextchar==?(
        super
      end
    end

    module NestedContexts
      class VContext<NestedContext
        def initialize(linenum)
          super("v","",linenum)
        end
        def see evt,lexer
          lexer.parsestack.pop if evt==:semi and lexer.readahead(1)!='('
        end
      end
    end

  end

  module ::RedParse::MacroMixin
    RedParse.constants.each{|k|
      const_set k, RedParse::const_get(k)
    }

    def redparse_modules_init
      if defined? @lexer and @lexer.respond_to? :enable_macros!
        @lexer.enable_macros!
        @lexer.extend ::RubyLexer::MacroMixin
        @lexer.rubylexer_modules_init
      end
      # binary
      @unary_or_binary_op=/^([\^:]|#@unary_or_binary_op)$/


      super
    end

    def PRECEDENCE
      result=super
      return result.merge({"^@"=>result["+@"], "v"=>result[";"]})
    end

    def RULES
      @@soft_nl||=KW(';')&-{:not_real? =>false}
      [
        -[KW('macro'), KW(beginsendsmatcher).~.*, KW('end'), KW(/^(do|\{)$/).~.la]>>MisparsedNode
      ]+super+[
        -['<+', Expr, '+>']>>FormEscapeNode, 
        -[Op('v'), Expr, lower_op()]>>FormEscapeNode, 
        -[Op('v'), Expr, /^;$|^<doubled-parens>$/, '(', Expr.-, ')']>>FormEscapeNode, #constructor needs update
        -[Op('v'), Expr, ';', KW('(').~.la]>>FormEscapeNode,
        -[Op('v'), Expr, @@soft_nl.la]>>:shift,
        -[Op('^@'), Expr, lower_op()]>>FormEscapeNode,
        -[Op(':@'), (ParenedNode&-{:size=>(0..1)})|(SequenceNode&-{:size=>0})]>>FormNode,
        -['macro', CallSiteNode, KW(';'),
           Expr.-, RescueNode.*, ElseNode.-, EnsureNode.-,
          'end'
         ]>>MacroNode,
        -[ '(', Expr.-, ')', '<doubled-parens>', '(', Expr.-, ')', BlockNode.-, KW('do').~.la]>>CallNode, #constructor needs update
      ]
    end
    def wants_semi_context
      super|KW('macro')
    end

    # A regex for all the keywords that can be terminated with the 'end'
    # keyword
    #
    # We use the base class's list, and add the 'macro' keyword to it.
    #
    def beginsendsmatcher
      return @bem||=/#{super}|^macro$/ 
    end

    def reduce_withs_directory
      "macro"
    end

    def rubyoperatorlist
      super+%w[:@ ^@ v] 
    end

    def rubykeywordlist
      super+%w[macro v]
    end

    def addl_node_containers; [::Macro] end

    def initialize(*args,&block)
      super
    end
  end
  Macro_ParserMixin=::RedParse::MacroMixin #old name

  class ::RedParse::WithMacros < RedParse
    include ::RedParse::MacroMixin
  end
  RedParseWithMacros=::RedParse::WithMacros #old name
end

#hacks to allow you to use macros within irb sessions.
#I wonder how portable this is to rubinius, jruby, mri 1.9, etc
module IRB
  class WorkSpace
    def evaluate(context, statements, file = __FILE__, line = __LINE__)
      Macro.eval(statements, @binding, file, line)
    end
  end
  ::RubyLex::ENINDENT_CLAUSE<<"macro"
  module ::RubyToken
    def_token(:TkMACRO,        TkId,  "macro",    EXPR_FNAME)
  end
  def IRB.require(file)
    Macro.require(file)
  end
end if defined? IRB
