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
  print i, ' '
  break if (i+=1)>=5
)
print "\n"

body=nil
formless_macro(loop2,[body],
  while true
    ^body
  end
)

i=0
loop2(
  print i, ' '
  break if (i+=1)>=5
)
print "\n"

macro formless_macro2(name,args=nil)
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
    Macro::FormNode[yield],
    [],nil,nil
  ]
end

formless_macro2(loop3){
  while true
    ^yield
  end
}

i=0
loop3{
  print i, " "
  break if (i+=1)>=3
}
print "\n"

body=nil
formless_macro2(loop4){
  while true
    ^yield
  end
}

i=0
loop4{
  print i, " "
  break if (i+=1)>=3
}
print "\n"

