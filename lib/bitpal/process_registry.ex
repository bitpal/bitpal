defmodule BitPal.ProcessRegistry do
  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def via_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  @spec get_process(any) :: {:ok, pid} | {:error, :not_found}
  def get_process(key) do
    case get_process_value(key) do
      {:ok, {pid, _}} -> {:ok, pid}
      err -> err
    end
  end

  @spec get_process_value(any) :: {:ok, {pid, term}} | {:error, :not_found}
  def get_process_value(key) do
    case Registry.lookup(__MODULE__, key) do
      [{pid, value}] ->
        {:ok, {pid, value}}

      [] ->
        {:error, :not_found}
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
