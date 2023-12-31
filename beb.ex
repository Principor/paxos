defmodule BestEffortBC do

  def start(name, neighbours, upper) do
    pid = spawn(BestEffortBC, :init, [name, neighbours, upper])
    # :global.unregister_name(name)
    case :global.re_register_name(name, pid) do
      :yes -> pid  
      :no  -> :error
    end
    IO.puts "registered #{name}"
    pid
  end

  def init(name, neighbours, upper) do 
    state = %{ 
        name: name, 
        upper: upper,
        neighbours: neighbours  
     }
     run(state)
  end

  def bc_send(bcast, msg) do
    send(bcast, {:input, :bc_send, msg})
  end

  def stop(bcast, pid) do
    send(bcast, {:stop, pid})
  end

  defp run({:stop, pid, name}) do 
    :global.unregister_name(name)
    send(pid, {:stopped, self()})
  end
  
  defp run(state) do
    my_pid = self()
    state = receive do 
      {:input, :bc_send, msg} -> 
        for p <- state.neighbours do
          case :global.whereis_name(p) do
            :undefined -> IO.puts("#{state.name}: lost connection to #{p}")
            pid -> 
              send(pid, {:relay_msg, state.name, msg})
          end
        end
        send(my_pid, {:output, :bc_receive, state.name, msg})
        state

      {:output, :bc_receive, origin, msg} -> 
        # IO.puts("#{inspect state.name} sending up #{inspect {:output, :bc_receive, origin, msg}}")
        send(state.upper, {:output, :bc_receive, origin, msg})
        state

      {:relay_msg, origin, msg} -> 
        # IO.puts "#{state.name} received #{inspect {:relay_msg, sender, origin, message_id, msg}}"
        send(my_pid,{:output, :bc_receive, origin, msg})
        state

      {:stop, pid} ->
        {:stop, pid, state.name}
    end
    run(state)
  end
          
end