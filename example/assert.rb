#this file uses macros! won't parse in normal ruby
macro assert(cond)
    if $Debug
      if RedParse::OpNode===cond and 
              /\A(?:[=!][=~]|[<>]=?|===)\Z/===cond.op
        #left,op,right=*cond
        left=cond.left; op=cond.op; right=cond.right
        :(fail 'expected '+^left.unparse+"(==#{^left}) to be "+
               ^op+" "+^right.unparse+"(==#{^right})" unless ^cond)    
      else
        :(fail "I expected that #{:(^^cond)}" unless ^cond)
      end
    end
end


#assert_equal... bah, who needs it?

def test_assert
  a=1 
  b=2

  assert a     #ok
  assert a!=b  #ok

  begin
    assert(a==b) #oops, fails. msg="expected a(==1) to be == b(==2)"
  rescue Exception=>e
    assert("expected a(==1) to be == b(==2)"== e.message) #better be ok
  else puts "exception expected but was not seen"
  end

  begin
    assert(!a) #oops, fails. msg="expected nil, but was not true"
  rescue Exception=>e
    assert("I expected that !a"== e.message) #better be ok
  else puts "exception expected but was not seen"
  end
  
  puts "all assertions passed"
end
