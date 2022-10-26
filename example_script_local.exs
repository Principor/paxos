:os.cmd('/bin/rm -f *.beam')

# Replace with your own implementation source files
IEx.Helpers.c "beb.ex"
IEx.Helpers.c "paxos.ex"
IEx.Helpers.c "uuid.ex"

IEx.Helpers.c "seat_reserve.ex"
# ##########

participants = [:srs1, :srs2, :srs3]

IO.puts("Starting replicated service...")
srs_pids = Enum.map(participants, fn name -> SeatReserve.start(name, participants) end)

Process.sleep(2000)
IO.puts("Started replicated service.")
IO.puts("===========================\n")

seatmap = SeatReserve.get_status_all(Enum.at(srs_pids,0))
IO.puts("Initial seatmap @ #{inspect Enum.at(srs_pids,0)} = \n #{inspect seatmap}")

status = SeatReserve.get_status(Enum.at(srs_pids,0), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,0)} = \n #{inspect status}")

IO.puts("Attempting to reserve row 5, seat 9 for Dan @ #{inspect Enum.at(srs_pids,0)}!")
SeatReserve.reserve(Enum.at(srs_pids,0), 5, 9, "Dan")
Process.sleep(500)

status = SeatReserve.get_status(Enum.at(srs_pids,0), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,0)} = \n #{inspect status}")

IO.puts("Attempting to reserve row 5, seat 9 for Alice @ #{inspect Enum.at(srs_pids,0)}!")
SeatReserve.reserve(Enum.at(srs_pids,0), 5, 9, "Alice")
IO.puts("Attempting to reserve row 5, seat 9 for Bob @ #{inspect Enum.at(srs_pids,1)}!")
SeatReserve.reserve(Enum.at(srs_pids,1), 5, 9, "Bob")
IO.puts("Attempting to reserve row 5, seat 9 for Charlie @ #{inspect Enum.at(srs_pids,2)}!")
SeatReserve.reserve(Enum.at(srs_pids,2), 5, 9, "Charlie")
Process.sleep(500)

status = SeatReserve.get_status(Enum.at(srs_pids,0), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,0)} = \n #{inspect status}")

status = SeatReserve.get_status(Enum.at(srs_pids,1), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,1)} = \n #{inspect status}")

status = SeatReserve.get_status(Enum.at(srs_pids,2), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,2)} = \n #{inspect status}")

# Kill one of the service replicas
IO.puts("Killing service replica #{inspect Enum.at(srs_pids,2)}!")
Process.exit(Enum.at(srs_pids,2), :kill)

# This will timeout...
IO.puts("Attempting to read status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,2)}...")
status = SeatReserve.get_status(Enum.at(srs_pids,2), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,2)} = \n #{inspect status}")

# But the other replicas should still be alive
status = SeatReserve.get_status(Enum.at(srs_pids,0), 5, 9)
IO.puts("Status of row 5, seat 9 @ #{inspect Enum.at(srs_pids,0)} = \n #{inspect status}")

IO.puts("\nUse SeatReserve.get_status/3, get_status_all/1, and reserve/4 to reserve and check bookings.")
IO.puts("In this script the service replica pids are bound to the variable srs_pids")
IO.puts("To access this in iex, you need to start iex like so:\n")
IO.puts("iex --dot-iex \"example_script_local.exs\"\n")
IO.puts("You can then play with the service using the SeatReserve API commands, e.g.:\n")
IO.puts("SeatReserve.get_status_all(Enum.at(srs_pids,0))\n")
IO.puts("Note you will have to implement Paxos for any of this to work!")
