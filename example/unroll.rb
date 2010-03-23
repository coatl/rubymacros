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

    #what if body contains next/redo? (break is ok)
    #was: fail if loop.body.rfind{|n| RedParse::KWCallNode===n and /^(?:next|redo)$/===n.ident }
    nexting=redoing=nil
    uniq=huh Macro.gensym
    loop.body.replace_flow_control(
      :next=>proc{fail; nexting=1; :(throw :"Unroll__Loop__next__#{huh ^uniq}")},
      :redo=>proc{fail; redoing=1; :(throw :"Unroll__Loop__redo__#{huh ^uniq}")}
    )
    if nexting or redoing
      loop.body.replace_flow_control(
        :break=>proc{|*a| ;;;;; 
          if a.size<=1
            :(throw :"Unroll__Loop__break__#{huh ^uniq}",^a.first)
          else
            :(throw :"Unroll__Loop__break__#{huh ^uniq}",^*a)
          end
        }
      )
      huh #wrap in appropriate catch(es)
      loop.body=:(catch(huh){^loop.body})
    end
    
    huh #should optimize some common flow control patterns like 
            #break at end of the block in toplevel
            #break in a if or unless stmt in toplevel

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
    else fail
    end
  else fail
  end
  return result
end


warn "these tests need to move to another file (unroll_wrap?) now"
=begin
unroll1(1,2,3){|x| p x}

i=1
unroll( while i<=3; p i; i+=1 end )
i=1
unroll( until i>3; p i; i+=1 end )
i=1
unroll( ( p i; i+=1 ) while i<=3 )
i=1
unroll( ( p i; i+=1 ) until i>3 )

unroll 3.times{|i| p i+1 }
unroll 8.times{|i| p i+1 }
unroll 9.times{|i| p i+1 }

=end
