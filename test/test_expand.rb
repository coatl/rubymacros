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



require 'test/unit'
require "macro"
class ExpandTest < Test::Unit::TestCase
  def test_simple_expand
    Macro.eval "macro simple(a,b) :(^a+^b) end"
    ttt=RedParse::CallNode[nil, "p", [RedParse::CallNode[nil, "simple", [RedParse::LiteralNode[1], 
      RedParse::LiteralNode[2]], nil, nil]], nil, nil]
    ttt.macro_expand(Macro::GLOBALS,{})

    assert_equal ttt.unparse({}),'p(1+2)'

    ttt=Macro.parse "p(simple(1,2))"
    ttt.macro_expand(Macro::GLOBALS,{})
    assert_equal ttt.unparse({}),'p(1+2)'
  end
end
