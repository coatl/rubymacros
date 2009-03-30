=begin doesn't work yet

#change the default receiver within the block from self to new_default
macro with(new_default,&block)
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
    p with "baz" do
      [
        @quux,  #=>999, not nil
        size   #=>3, not 99
      ]
    end
  end

  def size; 99 end
end
Foo.new.bar


=end

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
