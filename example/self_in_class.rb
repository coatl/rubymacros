macro foo_definer
  :( def self.foo; :foo end )
end

class K
  foo_definer
end

p K.foo  #should print ':foo'
