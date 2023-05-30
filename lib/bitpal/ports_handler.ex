defmodule BitPal.PortsHandler do
  alias BitPal.ProcessRegistry

  @range Application.compile_env!(:bitpal, [__MODULE__, :available])

  def assign_port do
    port = get_free_port()
    Registry.register(ProcessRegistry, via_tuple(port), port)
    port
  end

  def get_assigned_process(port) do
    ProcessRegistry.get_process(via_tuple(port))
  end

  def get_free_port do
    # It's not really efficient to loop and check all this way,
    # but it's done very rarely and we don't expect to use a lot of ports.
    Enum.find(@range, fn port ->
      case get_assigned_process(port) do
        {:ok, _} -> false
        {:error, :not_found} -> true
      end
    end)
  end

  defp via_tuple(port) do
    ProcessRegistry.via_tuple({__MODULE__, port})
  end
end
