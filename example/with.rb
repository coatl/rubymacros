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

=begin xform_tree! version, doesn't work yet (grrr)
#change the default receiver within the block from self to new_default
#kinda like instance_eval, except it doesn't affect instance vars
macro with(new_default)
  yield.xform_tree!(
    RedParse::CallNode&-{:receiver => NilClass>>new_default}
  )
end

#used like this:
class Foo
  def bar
    @quux=999
    p with( "baz" ){
      [
        @quux,  #=>999, not nil
        size   #=>3, not 99
      ]
    }
  end

  def size; 99 end
end
Foo.new.bar
=end

#change the default receiver within the block from self to new_default
#kinda like instance_eval, except it doesn't affect instance vars
macro with(new_default)
  block=yield
  block.walk{|parent,i,subi,node|
    if RedParse::CallNode===node and node.receiver.nil?
      node.receiver=new_default
    end
    true
  }
  return block
end

#used like this:
class Foo
  def bar
    @quux=999
    p with( "baz" ){
      [
        @quux,  #=>999, not nil
        size   #=>3, not 99
      ]
    }
  end

  def size; 99 end
end
Foo.new.bar

=begin old way
#change the default receiver within the block from self to new_default
macro with(new_default,block)
  block.walk{|parent,i,subi,node|
    if RedParse::CallNode===node and node.receiver.nil?
      node.receiver=new_default
    end
    true
  }  
  return block
end

#used like this:
class Foo
  def bar
    @quux=999
    p with "baz", [
      @quux,  #=>999, not nil
      size   #=>3, not 99
    ]
  end

  def size; 99 end
end
Foo.new.bar
=end
