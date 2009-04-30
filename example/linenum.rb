macro __DIR__
  :(File.dirname(__FILE__))
end

macro foo
  :(
    "just an example, to take up several lines,"+
    "so that line numbers might be messed up"
  )
end

def user_of_foo
  foo
end

def linenumuser
  p __LINE__ #should print 17
end
