=begin doesn't work yet
macro loop(&body)
  :(while true
     ^body
  )
end
=end

macro loop(body)
  :(while true
     ^body
    end
  )
end

def loop_user
  i=0
  loop(
    p i
    i+=1
    break if i>=10
  )
end
