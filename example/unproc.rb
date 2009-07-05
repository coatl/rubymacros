macro unproc0 pr
  pr.body
end

macro unproc(*args)
  yield(*args)
end


  unproc{
    p :foo
  }

