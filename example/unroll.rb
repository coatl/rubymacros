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

macro unroll(loop)
  $LOOP_MULTIPLIER||=4
  result=:( while true; end )
  result.body=RedParse::SequenceNode[]
  case loop
  when RedParse::LoopNode,RedParse::UntilOpNode,RedParse::WhileOpNode
    #what if body contains next/redo/retry? (break is ok)
    fail if loop.body.rfind{|n| RedParse::KWCallNode===n and /^(?:next|redo|retry)$/===n.ident }
    cond=loop.condition
    chec=if loop.reversed
           :(break if ^cond) unless RedParse::VarLikeNode===cond && /^(nil|false)$/===cond.ident
         else
           :(break unless ^cond) unless 
             RedParse::LiteralNode===cond or RedParse::VarLikeNode===cond && "true"==cond.ident
         end
    $LOOP_MULTIPLIER.times {
      result.body<<chec if chec
      result.body<<loop.body  
    }
  when RedParse::CallSiteNode
    fail if loop.block.rfind{|n| RedParse::KWCallNode===n and /^(?:next|redo|retry|break)$/===n.ident }
    if RedParse::LiteralNode===loop.receiver and "times"==loop.name and loop.params.nil?
      iterations=loop.receiver.val
      iter_var=loop.blockparams[0]
      warn "#{iter_var.name} was confined to #times block, but now leaks into caller's scope"
      if iterations<2*$LOOP_MULTIPLIER
        result=RedParse::SequenceNode[]
        iterations.times{|i|
          result<<:( (^iter_var) = ^i ) if iter_var
          result<<loop.block
        }
      else
        iter_var ||= VarNode["ii"]
        result=:( (^iter_var)  =  0; while ^iter_var<^(iterations-iterations%$LOOP_MULTIPLIER); end )
        inner=result.last
        inner.body=RedParse::SequenceNode[]
        $LOOP_MULTIPLIER.times{
          inner.body<<loop.block
          inner.body<<:( (^iter_var) += 1 )
        }
        sofar=iterations-iterations%$LOOP_MULTIPLIER
        sofar.upto(iterations-1){|i| 
          result<<:( (^iter_var) = ^i )
          result<<loop.block
        }
      end
    else fail
    end
  else fail
  end
  return result
end



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

