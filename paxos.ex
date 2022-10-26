defmodule Paxos do

	# name: A unique atom name for the Paxos process (e.g. :p0)
	# participants: Names of the other participants :p0, [:p1, :p2, :p3, :p4]
	# upper: pid of the app process to notify on decision
	def start(name, participants, upper) do
		IO.puts("Add your code here!")
	end

	# pid: process id of a Paxos replica
	# val: arbitrary value 
	# Set the input value of process pid to val.
	# *If* process pid subsequently becomes the 
	# leader (see start_ballot/1 below), it will
	# attempt to have the other processes decide on val if
	# no other value has already been decided. 
	def propose(pid, val) do 
		IO.puts("Add your code here!")
	end
	
	# pid: process id of a Paxos replica
	# Should cause process pid to start a new
	# ballot. Should only be invoked after propose/2 above.
	# Might be helpful to think of this function 
	# as telling process pid it is the leader.
	def start_ballot(pid) do
		IO.puts("Add your code here!")
	end

end
