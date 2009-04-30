SCRIPT_LINES__={}
require 'example/linenum_wrap.rb'

p SCRIPT_LINES__.keys.grep(/linenum/).each{|k|
  p k
  puts SCRIPT_LINES__[k]
}
