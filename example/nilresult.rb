macro nilresult
  nil
end


nilresult

p Macro.expand( "a; nilresult; b" ).unparse
