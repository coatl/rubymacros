macro pipeline stages
  result=:(begin end)

end


=begin
(0..9).map{|n| n+100 }.select{|n| n%2==0 }.inject(0){|sum,n| sum+n }

begin
sum=0
for x in (0..9) 
  x=x+100
  next if x%2==0
  sum=sum+x
end
sum
end
=end
