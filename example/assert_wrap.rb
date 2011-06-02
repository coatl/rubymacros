require 'macro'
$Debug=1
Macro.require 'example/assert'

test_assert

$Debug=nil
Macro.require 'example/assert_does_nothing_when_disabled'
