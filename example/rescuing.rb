macro rescuing_vars(method)
  method.body=:(
     begin
        ^method.body
     rescue => e; puts "rescuing" ; #raise
     end
  )
  return method
end

rescuing_vars def foo
  bar
end

foo
