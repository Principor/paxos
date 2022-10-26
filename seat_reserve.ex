defmodule SeatReserve do
    def start(name, participants) do
        spawn(SeatReserve, :init, [name, participants])
    end

    def init(name, participants) do
        # Create a separate Paxos service for each seat for this instance
        # of the seat reservation service (participant), i.e. for 10 rows
        # with 10 seats each, this participant should start 100 Paxos services. 
        #
        # The Paxos service for a specific seat should try to achieve consensus
        # with the corresponding Paxos services for the same seat at other replicas 
        # of the seat reservation service (participants). 
        seat_map = for i <- 1..10, j <- 1..10, into: %{} do
            procs = for p <- participants, do: get_name(p, i, j)
            pid = Paxos.start(my_name = get_name(name, i, j), procs, self)
            Process.link(pid)
            (fn {d, n} -> wait_for_majority(d, n, n / 2, my_name, my_name in d) end).
                ((fn d -> {d, MapSet.size(d)} end).(MapSet.new(procs)))
            # (row, seat) -> (paxos_pid, status, was_propose_called)
            {{i, j}, {pid, my_name, :free, false}}
        end
        IO.puts("#{name}: ready")
        run(seat_map)
    end

    defp wait_for_majority(_, n, q, _, false) when n < q, do: :done
    defp wait_for_majority(procs, _, q, name, _) do
        Process.sleep(10)
        s = Enum.reduce(procs, MapSet.new, 
            fn p, s -> if :global.whereis_name(p) != :undefined, do: MapSet.put(s, p), else: s end)
        (fn d -> wait_for_majority(d, MapSet.size(d), q, name, name in d) end).(MapSet.difference(procs, s))
    end

    defp get_name(proc, i, j), do: 
        String.to_atom(Atom.to_string(proc) <> "_" <> Integer.to_string(i) <> "_" <> Integer.to_string(j))

    # Simple asynchronous implementation.
    # The status can be queried with with
    # get_status/1 and get_status/3
    def reserve(srs, row, seat, user) do
        send(srs, {:reserve, row, seat, user})
	
	# The below would be a more 'synchronous' implementation.
        # send(srs, {:reserve, row, seat, user, self, req_id = UUID.string_to_binary!(UUID.uuid1())})
        # receive do:
        #     {status, req_id} -> status
        #     after 10000 -> :timeout
        # end
    end

    def get_status_all(srs) do
        send(srs, {:get_status_all, self, req_id = UUID.string_to_binary!(UUID.uuid1())})
        receive do
            {:seat_map, map, ^req_id} -> map
            after 10000 -> :timeout
        end
    end

    def get_status(srs, row, seat) do
        send(srs, {:get_status, row, seat, self, req_id = UUID.string_to_binary!(UUID.uuid1())})
        receive do
            {status, ^req_id} -> status
            after 10000 -> :timeout
        end 
    end

    # TODO: after submitting a reservation request, pick a random
    # delay from some fixed interval, after delay check if there was
    # progress, if not trigger start_ballot 

    # TODO: can use Enum.each for concurrent reservation testing

    defp run(seat_map) do    
        seat_map = receive do
            {:reserve, row, seat, user} -> 
                seat_map = case seat_map[{row, seat}] do
                    {pid, name, :free, false} -> 
                        Paxos.propose(pid, {row, seat, user})
                        # if name == get_name(:p1, row, seat), do: Paxos.start_ballot(pid)
                        # see TODO
                        Paxos.start_ballot(pid) 
                        %{seat_map | {row, seat} => {pid, name, :free, true}}
                    _ -> seat_map
                end
                seat_map

            {:decide, {row, seat, user}} ->
                {pid, name, _, _} = seat_map[{row, seat}]
                %{seat_map | {row, seat} => {pid, name, user, true}}

            {:get_status_all, pid, req_id} -> 
                send pid, 
                    {:seat_map, 
                    (for {k, {_, _, status, _}} <- seat_map, do: {k, status}), 
                    req_id}
                seat_map

            {:get_status, row, seat, pid, req_id} ->
                send pid, {elem(seat_map[{row, seat}], 2), req_id}
                seat_map
        end
        run(seat_map)
    end
end
