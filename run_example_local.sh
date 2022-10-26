killall -9 beam.smp 2>/dev/null
/bin/rm -f *.beam
iex --sname coord --dot-iex "example_script_local.exs"
