=begin surely doesn't work
macro formless_macro(name,args,body)
  :(
    macro ^name (^CommaOpNode[*args])
      :(^^body)
    end
  )
end
=end

macro formless_macro(name,args,body)
  argnames=args.map{|arg|
    case arg
    when RedParse::VarNode;  
      fail if /[A-Z$@]/===arg.name
      arg
    when RedParse::CallNode; 
      fail if /[A-Z$@]/===arg.name
      fail if arg.receiver or arg.params or arg.block
      RedParse::VarNode[arg.name]
    else fail
    end
  } if args
  Macro::MacroNode[nil,name.name,argnames,
    Macro::FormNode[body],
    [],nil,nil
  ]
end

#form escape not enclosed in a form... that's deeply weird
#i'm frankly surprised that this works...

formless_macro(loop,[body],
  while true
    ^body
  end
)

i=0
loop(
  puts i
  break if (i+=1)>=10
)

body=nil
formless_macro(loop2,[body],
  while true
    ^body
  end
)

i=0
loop(
  puts i
  break if (i+=1)>=10
)
