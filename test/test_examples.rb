=begin
    rubymacros - a macro preprocessor for ruby
    Copyright (C) 2008, 2016  Caleb Clausen

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'test/unit'
require "macro"

  def def_example_test(name,expect)
      define_method "test_example_#{(name).gsub('/','Y')}" do
        out,err=capture_std_out_err{
          load name
        }
#        p [expect,out]
        assert_equal expect,out
        assert empty_but_for_warns?(err), "expected no warnings, but saw these:\n"+err.gsub!(/^/,"  ")
      end
  end

  def capture_std_out_err #dangerous... hard to debug
    old={:O=>STDOUT.dup,:o=>$stdout,:E=>STDERR.dup,:e=>$stderr}
    o1,o2=IO::pipe
    e1,e2=IO::pipe
    STDOUT.reopen(o2)
    STDERR.reopen(e2)
    $stdout=STDOUT
    $stderr=STDERR
    begin
      yield
    ensure
      STDOUT.reopen old[:O]
      STDERR.reopen old[:E]
      $stdout,$stderr=old[:o],old[:e]
    end

    o2.close; e2.close
    out=o1.read
    err=e1.read 
    o1.close; e1.close

    return out,err
  end

  def empty_but_for_warns? str
    str=str.dup
    str.gsub!(/^([^:]+:\d+: warning: .*)$/){STDERR.puts $1;''}
    str.gsub!(/\n{2,}/,"\n")
    /\A\Z/===str
  end

class ExamplesTest<Test::Unit::TestCase
  def setup
    Macro.delete_all!
  end

  def self.example_dir
    macropath=$LOADED_FEATURES.grep(/macro\.rb$/)[0]
    unless %r{^[/\\]}===macropath
      macropath=$LOAD_PATH.find{|dir| File.exist? dir+"/macro.rb"}
    else
      macropath=File.dirname(macropath)
    end
    File.dirname(macropath)+"/example/"
  end

  StringNode=RedParse::StringNode
  can=File.read(example_dir+"/expected_output.txt").gsub(/^#.*$/,'').split(/^(.*) :\n/)
  can.shift
  #code=:()
#  warn "unroll example disabled for now"
  while name=can.shift
    expect=can.shift
    #code+=:(
    def_example_test(name,expect) #unless /unroll/===name
  end
  #Macro.eval code
  
end
