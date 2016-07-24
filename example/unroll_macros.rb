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

macro unroll0(ary,code)
  ary.inject(:()){|sum,x|
    sum + :(^code[x])
  }
end

macro unroll1(*ary)
  ary.inject(:()){|sum,x|
   sum + yield( x ) 
  }
end

module Unroll
  def self.unroll_loop loop
    result=:( while true; end )
    result.body=RedParse::SequenceNode[]
    body=loop.body.deep_copy

    #what if body contains redo? (break/next is ok)
    #was: fail if loop.body.rfind{|n| RedParse::KWCallNode===n and /^(?:next|redo)$/===n.ident }
    nexting=redoing=breaking=nil
    uniq= rand(0x1_0000_0000) #hacky!; should be: Macro.gensym
    body.replace_flow_control(
      #:next=>proc{ nexting=1; :(throw :"Unroll__Loop__next__#{^uniq}")},
      :redo=>proc{ redoing=1; :(throw :"Unroll__Loop__redo__#{^uniq}")}
    )
    if redoing
      #wrap in appropriate catches
      body=:(catch(:"Unroll__Loop__redo__#{^uniq}"){^body}) if redoing
    end
    
    warn "should optimize some common flow control patterns like"
    warn "break at end of the block in toplevel"
    warn "break in a if or unless stmt in toplevel"

    cond=loop.condition
    chec=if loop.reversed
           :(break if ^cond) unless RedParse::VarLikeNode===cond && /^(nil|false)$/===cond.ident
         else
           :(break unless ^cond) unless
             RedParse::LiteralNode===cond or RedParse::VarLikeNode===cond && "true"==cond.ident
         end
    $LOOP_MULTIPLIER.times {
      result.body<<chec.deep_copy if chec
      result.body<<loop.body.deep_copy
    }
    return result
  end

  def self.unroll_times loop
      result=:( while true; end ) 
      result.body=RedParse::SequenceNode[]

      fail if loop.block.rfind{|n| RedParse::KWCallNode===n and /^(?:next|redo|retry|break)$/===n.ident }
      iterations=loop.receiver.val
      iter_var=loop.blockparams[0]
      warn "#{iter_var.name} was confined to #times block, but now leaks into caller's scope"
      if iterations<2*$LOOP_MULTIPLIER
        result=RedParse::SequenceNode[]
        iterations.times{|i|
          result<<:( (^iter_var) = ^i ) if iter_var
          result<<loop.block.deep_copy
        }
      else
        iter_var ||= VarNode["ii"]
        result=:( (^iter_var)  =  0; while ^iter_var<^(iterations-iterations%$LOOP_MULTIPLIER); end )
        inner=result.last
        inner.body=RedParse::SequenceNode[]
        $LOOP_MULTIPLIER.times{
          inner.body<<loop.block.deep_copy
          inner.body<<:( (^iter_var) += 1 )
        }
        sofar=iterations-iterations%$LOOP_MULTIPLIER
        sofar.upto(iterations-1){|i| 
          result<<:( (^iter_var) = ^i )
          result<<loop.block.deep_copy
        }
      end
      return result
  end
end

warn "several unhandled cases in unroll macro"
macro unroll(loop)
  $LOOP_MULTIPLIER||=4
  case loop
  when RedParse::LoopNode,RedParse::UntilOpNode,RedParse::WhileOpNode
    Unroll.unroll_loop loop
  when RedParse::CallSiteNode
    if RedParse::LiteralNode===loop.receiver and "times"==loop.name and loop.params.nil?
      Unroll.unroll_times loop
    elsif loop.receiver.nil? and "loop"==loop.name and loop.params.nil?
      huh
    elsif "each"==loop.name and loop.params.nil?
      huh
    else fail
    end
  else fail
  end
end

