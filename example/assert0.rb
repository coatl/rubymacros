macro assert
    if $Debug
        :( p :hi )
    end
end

  begin
    assert
  end

if assert; 123 end
