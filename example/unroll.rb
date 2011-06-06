
unroll1(1,2,3){|x| p x}

i=1
unroll( while i<=3; p i; i+=1 end )
i=1
unroll( until i>3; p i; i+=1 end )
i=1
unroll( ( p i; i+=1 ) while i<=3 )
i=1
unroll( ( p i; i+=1 ) until i>3 )

unroll 3.times{|i| p i+1 }
unroll 8.times{|i| p i+1 }
unroll 9.times{|i| p i+1 }

