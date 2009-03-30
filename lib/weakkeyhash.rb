class WeakKeyHash<Hash
  def initialize(&block)
    super
  end


  def [](key)
    super key.__id__
  end

  def []=(key,val)
    ObjectSpace.define_finalizer(key,&method :delete)
    super key.__id__,val
  end

  #dunno how many more methods will actually work...
end
