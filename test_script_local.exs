:os.cmd('/bin/rm -f *.beam')

# Replace with your own implementation source files
IEx.Helpers.c "beb.ex"
IEx.Helpers.c "paxos.ex"

IEx.Helpers.c "test_harness.ex"
IEx.Helpers.c "paxos_test.ex"

# ##########


# Different configurations to run tests with
config_3_local = %{
        p1: {:local, {:val, 101}},
        p2: {:local, {:val, 101}},
        p3: {:local, {:val, 101}}
}

config_5_local = %{
        p1: {:local, {:val, 101}},
        p2: {:local, {:val, 102}},
        p3: {:local, {:val, 103}},
        p4: {:local, {:val, 104}},
        p5: {:local, {:val, 105}}
}

{:ok, hostname} = :inet.gethostname
host = to_string(hostname)
IO.puts("Host: " <> host)
# ###########

get_node = fn node -> String.to_atom(node <> "@" <> host) end

test_suite = [
#   test case, configuration, number of times to run the case, description
    {&PaxosTest.run_simple/3, config_3_local, 1, "No failures, no concurrent ballots"},
    {&PaxosTest.run_simple_2/3, config_3_local, 1, "No failures, 2 concurrent ballots"},
    {&PaxosTest.run_simple_many/3, config_5_local, 1, "No failures, many concurrent ballots"},
    {&PaxosTest.run_non_leader_crash/3, config_3_local, 1, "One non-leader crashes, no concurrent ballots"},
    {&PaxosTest.run_minority_non_leader_crash/3, config_5_local, 1, "Minority non-leader crashes, no concurrent ballots"},
    {&PaxosTest.run_leader_crash_simple/3, config_5_local, 1, "Leader crashes, no concurrent ballots"},
    {&PaxosTest.run_leader_crash_simple_2/3, config_5_local, 1, "Leader and some non-leaders crash, no concurrent ballots"}
]

validity_range = 100..105
if Node.self == get_node.("coord") do

  Enum.reduce(test_suite, length(test_suite), 
   fn ({func, config, n, doc}, acc) ->
      IO.puts(:stderr, "============")
      IO.puts(:stderr, "#{inspect doc}, #{inspect n} time#{if n > 1, do: "s", else: ""}")
      IO.puts(:stderr, "============")
      for _ <- 1..n do
              res = TestHarness.test(func, Enum.shuffle(Map.to_list(config)))
              IO.puts("Checking results: #{inspect res}")
              {vl, al, ll} = Enum.reduce(res, {[], [], []}, 
                 fn {_, _, s, v, a, {:message_queue_len, l}}, {vl, al, ll} -> 
                      if s != :killed, do: {[v | vl], [a | al], [l | ll]},
                      else: {vl, al, ll}
                 end
              )
              termination = :none not in vl
              agreement = termination and MapSet.size(MapSet.new(vl)) == 1
              {:val, agreement_val} = if agreement, do: hd(vl), else: {:val, -1}
              validity = agreement_val in validity_range 
              safety = agreement and validity
              too_many_attempts = (get_att = (fn a -> 10 - a + 1 end)).(Enum.max(al)) > 5
              too_many_messages_left = Enum.max(ll) > 10
              if termination and safety do
                      warn = if too_many_attempts, do: [{:too_many_attempts, get_att.(Enum.max(al))}], else: []
                      warn = if too_many_messages_left, do: [{:too_many_messages_left, Enum.max(ll)} | warn], else: warn
                      IO.puts(:stderr, (if warn == [], do: "PASS", else: "PASS (#{inspect warn})"))
              else
                      IO.puts(:stderr, "FAIL\n\t#{inspect res}")
              end
      end
      IO.puts(:stderr, "============#{if acc > 1, do: "\n", else: ""}")
      acc - 1 
   end)
   System.halt
end
