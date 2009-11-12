macro separated_scope
  code=yield
  localnames=[]
  code.depthwalk{|parent,i,j,node|
    if RedParse::VarNode===node
      node.name<<'_'
      localnames<<node.name
    end
  }
  :(
    ^localnames.uniq.inject(:(nil)){|sum,lvar| 
      RedParse::AssignNode[ RedParse::VarNode[lvar],'=',sum ] 
    }
    eval local_variables.map{|lvar| lvar+"_="+lvar}.join(';')
    ^code
  )
end

a = 10
separated_scope do
a = a + 1
p a #=>11
end 
p a #=>10
