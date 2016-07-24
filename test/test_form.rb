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

$VERBOSE=1

require "macro"
require 'test/unit'
require 'rubygems'
require 'rubylexer'
require "rubylexer/test/testcases" #from rubylexer
require 'pp'


class FormTest< Test::Unit::TestCase
  def setup
    Macro.delete_all!
  end

  EXAMPLES=TestCases::TESTCASES

  SLOW=ENV['SLOW']

  warn "some form tests disabled; set SLOW to enable them" unless SLOW
  warn "some Macro.expand tests disabled; set SLOW to enable them" unless SLOW

  nullfile= File.open(File.exist?( "/dev/null" )? "/dev/null" : "dev_null","w")

  EXAMPLES.uniq.each_with_index{|x,i|
    next if /__END__/===x
    begin
      #old_VERBOSE=$VERBOSE;$VERBOSE=false
      oldSTDERR=STDERR.dup; STDERR.reopen(nullfile)
      catch(:foo){ eval "BEGIN{throw :foo};"+x }
    rescue SyntaxError
      next
    #ensure $VERBOSE=old_VERBOSE
    ensure STDERR.reopen(oldSTDERR)
    end
    if / \^[^\s]/===x #and x.size>1000
      while x['^']
        warn "disabling tests of '#{x[/^.*\^.*$/]}'"
        x[/^.*\^.*$/]=''
      end
      next
    end
    x.gsub!('v','vv')  #hacky
    escaped=x.gsub(/[^ -~]/){|ch| 
      ch=ch[0]
      ch=ch.getbyte 0 if ch.respond_to? :getbyte
      "\\x"+ch.to_s(16)
    }
    define_method "test_form_around_#{escaped}" do
      check x
    end if SLOW or rand<0.5
    define_method "test_form_and_escape_around_#{escaped}" do
      if /\A *undef /===x
        err=RedParse::ParseError
      end
      begin
        check_for_syntax_error x
      rescue err||NilClass #ignore
      else fail "#{err} expected, but none occurred"  if err
      end
    end if SLOW or rand<0.5 unless /\A\s*(?:=begin|return|next|break)/===x
    define_method "test_form_and_call_and_escape_around_#{escaped}" do
      if /\A *undef /===x
        err=RedParse::ParseError
      end
      begin
        check_for_syntax_error x, ":(foo(^","\n))"
      rescue err||NilClass #ignore
      else fail "#{err} expected, but none occurred"  if err
      end
    end if SLOW or rand<0.5 unless /\A\s*(?:=begin|return|next|break)/===x
    define_method "test_Macro.expand_of_#{escaped}" do
      check_for_syntax_error x,"",""
    end if SLOW or rand<0.5
  }
  warn "#{__FILE__}:#{__LINE__}: warning: tests of :(^...) and Macro.expand are weak"

  def check(code,pre="\n",post="\n")
    #begin
#      puts code
      begin  as_form=Macro.eval(":("+pre+code+post+")")
      rescue Exception=>formexc
       0
      end

      begin  
        as_tree=RedParse.new("  \n"+code).parse
        as_tree=RedParse::SequenceNode[] if RedParse::NopNode===as_tree
      rescue Exception=>treeexc
       0
      end

      errs=[formexc,treeexc].compact
      raise errs.first if errs.size==1

#      as_form.delete_extraneous_ivars! if as_form
#      as_tree.delete_extraneous_ivars! if as_tree

      if as_tree and as_form and as_tree.offset != as_form.offset
        warn "form and parse tree did not have same offsets, input: '#{code}'"
        as_form.instance_variable_set :@offset, as_tree.offset
      end
      assert_equal as_tree, as_form

      assert_equal as_form, as_form.deep_copy if as_form
    #end
  end
  def check_for_syntax_error(code,pre=":(^",post="\n)")
#      puts code
      as_form=Macro.expand(pre+code+post)

      assert_equal as_form, as_form.deep_copy
      assert_unparses_wo_syntax_error(as_form) #weak weak
  end

  @@auwose=0
  def assert_unparses_wo_syntax_error(tree) #weak test
      warn "using assert_unparses_wo_syntax_error, which is weak" if (@@auwose+=1)==1
      catch(:foo){
        old_STDERR=$stderr
        $stderr=open("/dev/null",'w') if File.exist? "/dev/null"
        begin  
          eval "BEGIN{throw :foo};"+tree.unparse #weak test
        ensure $stderr=old_STDERR if File.exist? "/dev/null"
        end
      } 
  end
end

class FormParameterTest< Test::Unit::TestCase
  def setup
    Macro.delete_all!
  end
  DATA=[
    "1", "1.1", "nil", "false", "true",
    "[1,2,3]", "{'a'=>4,:b=>6}", "'s'", 
  ]
  DIFFICULT_CHILDREN=[
    "RedParse::ConstantNode[nil,'Object']","(a=[];a<<a)"
  ]

  def form_param_setup datum
      $a=[]
      $b=[]
      Macro.eval(":($a.push(^#{datum}))").eval
      datum=eval datum
  end

  def test_form_params
    DATA.each{|datum|
      datum=form_param_setup datum
      $b.push datum

      assert_equal( $b, $a)
    }
  end

  def test_form_params_dc
    DIFFICULT_CHILDREN.each{|datum|
      datum=form_param_setup datum
      if RedParse::Node===datum
        $b.push datum.eval
      else
        $b.push datum
      end

      assert_equal( $b.inspect, $a.inspect) #byaah, not the best way....
    }
  end

  def test_escape_from_inner_form
    Macro.parse ":(:(ielf=^rec))"
    Macro.eval ":(:(ielf=^rec))"
  end

  def test_marshal_of_form_param_with_hash

    #why is this failing??? seems like a marshal bug??
    #seems to be fixed in mri 1.9.2
    tree=Macro.parse ":(^{'ffdf'=>4})"
    assert_nothing_raised{
      dumped=Marshal.dump tree
      Marshal.load dumped
    }
    assert_nothing_raised{
      dumped=Marshal.dump tree
      Marshal.load dumped
    }
  end
end
