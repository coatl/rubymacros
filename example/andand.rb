macro andand(a,b)
  :(^a and ^b)
end

def main
  andand(false,puts("FAILED!!!"))
  andand(true,puts("Success!"))
end

main #if $0==__FILE__
