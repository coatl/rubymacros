# Role base class. Use SimpleDelegator instead?
class Role
  def initialize(mappings)
    @mappings = mappings
  end
  attr :mappings
end
 
# Context (UseCase) base class.
class Context
end

macro context_class name, roles, verbs
lc_roles=roles.map{|role| 
  ConstantNode===role or fail
  role.unparse.downcase.gsub("::","__") 
}
sym_roles=lc_roles.map{|role|
  LiteralNode[role]
}
at_roles=lc_roles.map{|role|
  VarNode["@"+role]
}
var_roles=lc_roles.map{|role|
  VarNode[role]
}
:(
# We can think of a context as setting a scene.
class ^name < Context
  attr_accessor ^*sym_roles
  def initialize(^*var_roles)
    ^*at_roles = ^*var_roles
  end
  ^verbs.map{|verb| context_verb(^*verb) }
end
)
end

macro context_verb(name, *args)
  :(:(
    def ^^name(^^*args,&block)
      ^*roles.zip(at_roles).map{|role,var|
        :((^var).(^eval(role.unparse).mappings[name])(^^*args,&block))
      }
    end
  ))
end

 
 
# --- example ---
 
# Mixins are fixed roles.
class Balance
  def initialize
    @balance = 0
  end
  def availableBalance
    @balance
  end
  def increaseBalance(amount)
    @balance += amount
    puts "Tranfered from account #{__id__} $#{amount}"
  end
  def decreaseBalance(amount)
    @balance -= amount
    puts "Tranfered to account #{__id__} $#{amount}"
  end
end
 
Balance::TransferSource= Role.new :transfer => :decreaseBalance
Balance::TransferDestination= Role.new :transfer => :increaseBalance

context_class Balance::Transfer, 
  Balance::TransferSource, Balance::TransferDestination,
  [transfer, amount]
 
class Account<Balance
  # An account by definition has a balance.
end
 
acct1 = Account.new
acct2 = Account.new
 
Balance::Transfer.new(acct1, acct2).transfer(50)
