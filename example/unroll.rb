macro unroll0(ary,code)
  ary.inject(:()){|sum,x|
    sum + :(^code[x])
  }
end

macro unroll(*ary)
  ary.inject(:()){|sum,x|
   sum + yield( x ) 
  }
end

unroll(1,2,3){|x| p x}
