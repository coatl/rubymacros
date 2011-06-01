class RedParse
class Node
  def replace_flow_control(replacer)
    fail "retry is hard! & changes semantics in ruby 1.9" if replacer[:retry]
    return_yield={}
    return_yield[:return]=replacer[:return] if replacer[:return]
    return_yield[:yield]=replacer[:yield] if replacer[:yield]
    walk{|parent,i,j,node|
      case node
      when KWCallNode
        if action=replacer[node.name.to_sym]
          newnode=action[*node.params]
          if j
            parent[i][j]=newnode
          else
            parent[i]=newnode
          end
        end
        true
      when LoopNode, UntilOpNode, WhileOpNode
        #nested loops hide break/next/redo
        node.condition.replace_flow_control(replacer)
        node.body.replace_flow_control(return_yield) if node.body and !return_yield.empty?
        false
      when MethodNode,ClassNode,ModuleNode,MetaClassNode
        node.receiver.replace_flow_control(replacer) if node.receiver
        #but not in body, rescues, else, ensure
        false
      when CallNode
        node.receiver.replace_flow_control(replacer) if node.receiver
        node.params.each{|param| param.replace_flow_control(replacer) } if node.params
        #but only return/yield in block or blockparams
        unless return_yield.empty?
          node.blockparams.each{|bparam| bparam.replace_flow_control(return_yield) } if node.blockparams
          node.block.replace_flow_control(return_yield) if node.block
        end
        false
      when Macro::FormNode
        #should really recurse in corresponding form escapes....
        false
      else true
      end
    }
  end
end
end
