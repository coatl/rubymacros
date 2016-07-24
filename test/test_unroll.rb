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
require 'macro'
Macro.require 'example/unroll'

class UnrollTest<Test::Unit::TestCase
  def setup
    Macro.delete_all!
  end

  def setup(seed=Time.now.to_i)
    srand(seed)
    @data=loop()
  end

  def choose(list)
    list[rand(list.size)]
  end

  def loop
    choose(LOOPS).
      gsub!("<<<cond>>>", loop_condition).
      gsub!("<<<body>>>", loop_body)
  end

  def loop_condition
    choose(LOOP_CONDITIONS)
  end

  def loop_body max=4
    x=rand(20)
    size=
    if x==0; 0
    else case x/2
         when 1; 1
         when 2; 2
         when 9; 10
         else 4
         end
    end
    result=(1..size).map{ choose(LOOP_BODY_PARTS) }.join("\n")
    if max>=0
      result.gsub!("<<<body>>>", loop_body(max-1))
    else
      result.gsub!("<<<body>>>", "nil")
    end
    result.gsub!("redo(","log(")
    result
  end

  LOOPS=[
    "while <<<cond>>>\n  <<<body>>>\nend\n",
    "until <<<cond>>>\n  <<<body>>>\nend\n",
    "(\n<<<body>>>\n)while <<<cond>>>\n",
    "(\n<<<body>>>\n)until <<<cond>>>\n",
    "begin\n<<<body>>>\nend while <<<cond>>>\n",
    "begin\n<<<body>>>\nend until <<<cond>>>\n",
  ]
  LOOP_CONDITIONS=[
    "true", "false", "rand<0.5", "rand<0.95"
  ]
  LOOP_BODY_PARTS=[
    "log(rand(100))", 
    "<<<fctl>>> if(rand<0.5)", 
    "<<<fctl>>> unless(rand<0.5)", 
    "<<<fctl>>>(<<<body>>>) if(rand<0.5)", 
    "<<<fctl>>>(<<<body>>>) unless(rand<0.5)", 
    "if(rand<0.5)\n  <<<body>>>\nend", 
    "unless(rand<0.5)\n  <<<body>>>\nend", 
    "log((<<<body>>>))",
  ]
  
  FCTLS=%w[break next redo]

  def clear_log; @log=[] end
  def log x; @log<<x end

  def test_unroll
    10.times{ 
      clear_log
      normal=eval(@data)
      nlog=@log

      clear_log
      macrod=Macro.eval("unroll #@data") 
      mlog=@log

      assert_equal normal,macrod
      assert_equal nlog,mlog
    }
  end

  def test_unroll_thorough times=1000,keys=(1..times).map{rand(0x1_0000_0000)}
    keys.each{|key| 
      begin
        setup key
        test_unroll
      rescue Exception=>e
        raise e.class,"using setup key #{key}"+e.message,e.backtrace
      end
    }
  end
end
