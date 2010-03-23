macro inline(method)
  #block/&param must be re-varified if used more than once
  #lvar defns in block should be scoped to just the block
  #maybe block should always remain a proc, rather than inlining it?

  #some things aren't supported in inline methods (yet)
  #return|redo|retry|yield keywords, & parameter, and optional args are disallowed
  fail if method.rfind{|n| RedParse::KWCallNode===n and /^(?:return|redo|retry|yield)$/===n.ident }
  if params=method.params
    fail if RedParse::UnaryAmpNode===params.last
    last_non_star=params.last
    last_non_star=params[-2] if RedParse::UnaryStarNode===last_non_star
    fail if RedParse::AssignNode===last_non_star
  end

  result=:(:(inline_self=^receiver; begin end))
  pre=result.val
  body=result.val[-1]

  #copy method innards to begin node
  body.body=method.body
  body.rescues=method.rescues
  body.ensure=method.ensure
  body.else=method.else

  #make a list of known params to inline method
  params={}
  #params should be re-varified to ensure theyre evaled exactly once
  #without hygienic macros, param names (+inline_self) leak into the caller!
  method.params.each{|param|
    case param
    when RedParse::VarNode
      params[param.name]=1
#      pre[0]+= :( :((^^param)=^param) )
    when RedParse::UnaryStarNode,RedParse::UnAmpNode
      param=param.val
      params[param.name]=1
#      pre[0]+= :( :((^^param)=^param) )
    when RedParse::AssignNode
      default=param.right
      param=param.left
      params[param.name]=1
#      pre[0]+= :( :((^^param)=^param||^default) )
    end
  } if method.params

  inline_self=RedParse::VarNode["inline_self"]

  body.walk{|parent,i,subi,node|
    newnode=nil
    case node
    when RedParse::VarNode
      #search method for params and escape them
      if params[node.name]
        newnode=RedParse::ParenedNode[Macro::FormEscapeNode[node]]
      end

    #what to do with receiver? implicit and explicit refs must be replaced
    when RedParse::VarLikeNode
      newnode=inline_self if node.name=="self"
    when RedParse::CallNode
      node.receiver||=inline_self 

    end
    if newnode
      if subi
        parent[i][subi]=newnode
      else
        parent[i]=newnode
      end
    end
    true
  }


  result= Macro::MacroNode[nil,method.name,method.params,result]
  p result.unparse
  return result
end
