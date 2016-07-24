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
  else fail "exception expected but was not seen"
  end

  begin
    assert(!a) #oops, fails. msg="expected nil, but was not true"
  rescue Exception=>e
    assert(/^I expected that ! *a$/=== e.message) #better be ok
  else fail "exception expected but was not seen"
  end
  
  puts "all assertions passed"
end
