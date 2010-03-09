macro inline(method)
  #some things aren't supported in inline methods (yet)
  fail if method.rfind{|n| KWCallNode===n and /^(?:return|redo|retry|yield)$/===n.ident }
  fail if RedParse::UnaryAmpNode===method.params.last
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
  method.params.each{|param|
    case param
    when VarNode
      params[param.name]=1
      pre.unshift huh
    when UnaryStarNode,UnAmpNode
      params[param.val.name]=1
      pre.unshift huh
    when AssignNode
      params[param.left.name]=1
      pre.unshift huh
    end
  }

  inline_self=VarNode["inline_self"]

  result.walk{|parent,i,subi,node|
    newnode=nil
    case node
    when VarNode
      if params[node.name]
        huh
      end

    when VarLikeNode
      newnode=inline_self if node.name=="self"
      

    end
    if newnode
      if subi
        parent[i][subi]=newnode
      else
        parent[i]=newnode
      end
    end
  }

  huh if method contains a return/redo/retry
  huh if method contains a yield
  huh if method contains a &param
  huh search method for params and escape them
  huh params should be re-varified to ensure theyre evaled exactly once
  huh block/&param must be re-varified if used more than once
  huh lvar defns in block should be scoped to just the block
  huh maybe block should always remain a proc, rather than inlining it?
  huh what to do with receiver? implicit and explicit refs must be replaced
  huh what to do with optional parameters?

  return MacroNode[nil,method.name,method.params,result]
end
