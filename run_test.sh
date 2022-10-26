killall -9 beam.smp 2>/dev/null
/bin/rm -f *.beam
elixir --sname alice test_script.exs 2>1 >/dev/null &
elixir --sname bob test_script.exs 2>1 >/dev/null &
elixir --sname charlie test_script.exs 2>1 >/dev/null &
elixir --sname darren test_script.exs 2>1 >/dev/null &
elixir --sname elias test_script.exs 2>1 >/dev/null &
elixir --sname coord test_script.exs
