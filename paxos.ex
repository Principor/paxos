defmodule Paxos do

	# name: A unique atom name for the Paxos process (e.g. :p0)
	# participants: Names of the other participants :p0, [:p1, :p2, :p3, :p4]
	# upper: pid of the app process to notify on decision
	def start(name, participants, upper) do
		pid = spawn(Paxos, :run, [nil, 0, participants, upper, false, 0, nil, 0])
		:global.register_name(name, pid)
		pid
	end

	# pid: process id of a Paxos replica
	# val: arbitrary value
	# Set the input value of process pid to val.
	# *If* process pid subsequently becomes the
	# leader (see start_ballot/1 below), it will
	# attempt to have the other processes decide on val if
	# no other value has already been decided.
	def propose(pid, val) do
		send(pid, {:propose, val})
	end

	# pid: process id of a Paxos replica
	# Should cause process pid to start a new
	# ballot. Should only be invoked after propose/2 above.
	# Might be helpful to think of this function
	# as telling process pid it is the leader.
	def start_ballot(pid) do
		send(pid, {:start_ballot})
	end

	def run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot) do
		receive do
			{:propose, new_value} ->
				run(new_value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)

			# Leader messages
			{:start_ballot} ->
				send_all({:prepare, ballot+1, self()}, participants)
				run(value, ballot+1, participants, upper, true, replies, highest_value, highest_ballot)

			{:promise, new_ballot, old_ballot, old_value} ->
				if ballot == new_ballot do
					{highest_value, highest_ballot} =
						if old_ballot > highest_ballot do
							{old_value, old_ballot}
						else
							{highest_value, highest_ballot}
						end
					new_replies = replies + 1
					others = length(participants) - 1
					if replies >= others - replies do
						accepted_value =
							if highest_value == nil do
								value
							else
								highest_value
							end
						send_all({:propose, accepted_value, ballot, self()}, participants)
						run(accepted_value, ballot, participants, upper, leader, 0, highest_value, highest_ballot)
					else
						run(value, ballot, participants, upper, leader, new_replies, highest_value, highest_ballot)
					end
				else
					run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				end

			{:reject, old_ballot, new_ballot} ->
				if old_ballot == ballot do
					send_all({:prepare, new_ballot+1, self()}, participants)
					run(value, new_ballot+1, participants, upper, leader, replies, highest_value, highest_ballot)
				else
					run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				end

			{:accept, new_value, new_ballot} ->
				if value == new_value and ballot == new_ballot do
					new_replies = replies + 1
					others = length(participants) - 1
					if replies >= others - replies do
						send_all({:decide, value}, participants)
						send(upper, {:decide, value})
						run(value, ballot, participants, upper, leader, new_replies, highest_value, highest_ballot)
					else
						run(value, ballot, participants, upper, leader, new_replies, highest_value, highest_ballot)
					end
				else
					run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				end


			# Acceptor messages
			{:prepare, new_ballot, pid} ->
				if new_ballot > ballot do
					send(pid, {:promise, new_ballot, ballot, value})
					run(value, new_ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				else
					send(pid, {:reject, new_ballot, ballot})
					run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				end

			{:propose, new_value, new_ballot, pid} ->
				if new_ballot >= ballot do
					send(pid, {:accept, new_value, new_ballot})
					run(new_value, new_ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				else
					send(pid, {:reject, new_ballot, ballot})
					run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				end

			{:decide, new_value} ->
				send(upper, {:decide, new_value})
				run(new_value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)

			after 5000 ->
				if leader do
					send_all({:prepare, ballot+1, self()}, participants)
					run(value, ballot+1, participants, upper, true, replies, highest_value, highest_ballot)
				else
					run(value, ballot, participants, upper, leader, replies, highest_value, highest_ballot)
				end
		end
	end

	def send_all(msg, participants) do
		for participant <- participants do
			pid = :global.whereis_name(participant)
			if pid != self() and pid != :undefined, do: send(pid, msg)
		end
	end
end
