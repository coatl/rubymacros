=begin
    rubymacros - a macro preprocessor for ruby
    Copyright (C) 2008  Caleb Clausen

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

# TODO: add a test for a method definition inside of a method definition
# to ensure that the inner method definition is properly postponed

$VERBOSE=1


require 'test/unit'
require "macro"


class ExpandTest < Test::Unit::TestCase
  def setup
    Macro.delete_all!
  end

  def test_simple_expand
    Macro.eval "macro simple(a,b) :(^a+^b) end"
    ttt=RedParse::CallNode[nil, "p", [RedParse::CallNode[nil, "simple", [RedParse::LiteralNode[1], 
      RedParse::LiteralNode[2]], nil, nil]], nil, nil]
    ttt.macro_expand(Macro::GLOBALS,{})

    assert_equal ttt.unparse,'p((1+2))'

    ttt=Macro.parse "p(simple(1,2))"
    ttt.macro_expand(Macro::GLOBALS,{})
    assert_equal ttt.unparse,'p((1+2))'
  end

  def test_expands_to_nil
    Macro.eval "macro nilmacro; nil end"
    tree=Macro.parse "foo; nilmacro; bar"
    tree=Macro.expand tree
    assert RedParse::SequenceNode===tree
    assert_equal 2, tree.size
    assert RedParse::CallNode===tree.first
    assert_equal "foo", tree.first.name
    assert RedParse::CallNode===tree.last
    assert_equal "bar", tree.last.name
   
    tree=Macro.parse "nilmacro; bar"
    tree=Macro.expand tree
    tree=tree.first if RedParse::SequenceNode===tree and tree.size==1
    assert RedParse::CallNode===tree
    assert_equal "bar", tree.name
   
    tree=Macro.parse "foo; nilmacro"
    tree=Macro.expand tree
    tree=tree.first if RedParse::SequenceNode===tree and tree.size==1
    assert RedParse::CallNode===tree
    assert_equal "foo", tree.name
   
    tree=Macro.parse "nilmacro"
    tree=Macro.expand tree
    assert RedParse::NopNode===tree
  end

  def test_unparse_form_escape_on_assign_lhs
    tree=Macro.parse "(^a)=^b"
    assert_match( /\(\^a\) *= *\^b/, tree.unparse )

    tree=Macro.parse '(^x),(^w), =^y'
    assert_match( /\(\^x\), \(\^w\), *= *\^y/, tree.unparse )
  end

  def test_call_method_on_form
    $bar=2
    assert_operator 0, :<, Macro.eval( ":(foo ^$bar).size" )
  end
end
