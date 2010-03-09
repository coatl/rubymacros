  def Context roles, verbs
    lc_roles=roles.map{|role| 
      role.downcase.gsub("::","__") 
    } 
    sym_roles=lc_roles.map{|role|
      ":"+role
    }.join(',')
    at_roles=lc_roles.map{|role|
      "@"+role
    }
    var_roles=lc_roles.join(',')
    result=Class.new(Context)
    result.class_eval "
      # We can think of a context as setting a scene.
        attr_accessor #{sym_roles}
        def initialize(#{var_roles})
          #{at_roles.join ','} = #{var_roles}
        end
        #{verbs.map{|verb| Context.verb(roles.zip(at_roles), verb) }.join("\n")}
    "
    return result
  end

# Context (UseCase) base class.
class Context
  def self.verb(roles_n_vars, name)
    "
      def #{name}(*args, &block)
        #{roles_n_vars.map{|role,var|
          "#{var}.#{eval(role)[name.to_sym]}(*args, &block)"
        }.join("\n")}
      end
    "
  end
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
 
Balance::TransferSource= { :transfer => :decreaseBalance }
Balance::TransferDestination= { :transfer => :increaseBalance }

Balance::Transfer=Context(
  %w[Balance::TransferSource Balance::TransferDestination],
  %w[transfer]
)

class Account<Balance
  # An account by definition has a balance.
end
 
acct1 = Account.new
acct2 = Account.new
 
Balance::Transfer.new(acct1, acct2).transfer(50)
