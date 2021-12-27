defmodule BitPal.BackendManager do
  use Supervisor
  alias BitPal.Backend
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice

  @type server_name :: atom | {:via, term, term} | pid
  @type backend_spec() :: Supervisor.child_spec()
  @type backend_name() :: atom

  # Startup

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(opts) do
    opts = Enum.into(opts, %{})
    name = Map.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: opts[:name] || __MODULE__,
      restart: :transient,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec register(Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register(invoice) do
    case fetch_backend(invoice.currency_id) do
      {:ok, ref} -> Backend.register(ref, invoice)
      {:error, _} -> {:error, :backend_not_found}
    end
  end

  # Individual backends

  @spec fetch_backend(Currency.id()) :: {:ok, Backend.backend_ref()} | {:error, :not_found}
  def fetch_backend(currency_id) do
    Backend.via_tuple(currency_id)
    |> ProcessRegistry.get_process_value()
  end

  @spec start_backend(server_name, backend_spec) :: Backend.backend_ref()
  def start_backend(name \\ __MODULE__, backend) do
    start_or_update_backend(name, backend)
  end

  @spec status(Currency.id()) :: :ok | :not_found
  def status(currency_id) do
    case fetch_backend(currency_id) do
      {:ok, _} -> :ok
      _ -> :not_found
    end
  end

  # Supervised backends

  @spec backends(server_name) :: [{backend_name(), Backend.backend_ref(), :ok, [Currency.id()]}]
  def backends(name \\ __MODULE__) do
    Supervisor.which_children(name)
    |> Enum.map(fn {name, pid, _worker, [backend]} ->
      ref = {pid, backend}
      {name, ref, :ok}
    end)
  end

  @spec currencies(server_name) :: [{Currency.id(), :ok, Backend.backend_ref()}]
  def currencies(name \\ __MODULE__) do
    backends(name)
    |> Enum.map(fn {_name, ref, status} ->
      {ref, status, Backend.supported_currencies(ref)}
    end)
    |> Enum.reduce([], fn {ref, status, currencies}, acc ->
      Enum.reduce(currencies, acc, fn currency, acc ->
        [{currency, status, ref} | acc]
      end)
    end)
  end

  @spec currency_list(server_name) :: [Currency.id()]
  def currency_list(name \\ __MODULE__) do
    currencies(name)
    |> Enum.reduce([], fn {currency, _, _}, acc -> [currency | acc] end)
    |> Enum.sort()
  end

  # Configuration

  @spec config_change(server_name, keyword, keyword, keyword) :: :ok
  def config_change(name \\ __MODULE__, changed, _new, _removed) do
    config_change(name, changed)
  end

  @spec config_change(server_name, keyword) :: :ok
  def config_change(name \\ __MODULE__, changed) do
    if backends = Keyword.get(changed, :backends), do: update_backends(name, backends)
  end

  @spec update_backends(server_name, backend_spec()) :: :ok
  defp update_backends(name, backends) do
    to_keep =
      backends
      |> Enum.map(fn backend -> start_or_update_backend(name, backend) end)
      |> Enum.reduce(MapSet.new(), fn {pid, _}, acc -> MapSet.put(acc, pid) end)

    Supervisor.which_children(name)
    |> Enum.each(fn {child_id, pid, _, _} ->
      if !MapSet.member?(to_keep, pid) do
        terminate_child(name, child_id)
      end
    end)
  end

  defp start_or_update_backend(name, spec = {backend, opts}) do
    case Supervisor.start_child(name, spec) do
      {:error, {:already_started, pid}} when is_pid(pid) ->
        Backend.configure({pid, backend}, opts)
        {pid, backend}

      {:ok, pid} when is_pid(pid) ->
        {pid, backend}
    end
  end

  defp start_or_update_backend(name, backend) when is_atom(backend) do
    start_or_update_backend(name, {backend, []})
  end

  def terminate_backends(name \\ __MODULE__, backends) when is_list(backends) do
    to_terminate =
      backends
      |> Enum.reduce(MapSet.new(), fn {pid, _module}, acc ->
        MapSet.put(acc, pid)
      end)

    Supervisor.which_children(name)
    |> Enum.each(fn {child_id, pid, _, _} ->
      if MapSet.member?(to_terminate, pid) do
        terminate_child(name, child_id)
      end
    end)
  end

  defp terminate_child(name, child_id) do
    Supervisor.terminate_child(name, child_id)
    Supervisor.delete_child(name, child_id)
  end

  # Server API

  @impl true
  def init(opts) do
    children =
      Map.get(opts, :backends, BitPalSettings.currency_backends())
      |> add_allow_parent_opt(opts)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def add_allow_parent_opt(backends, manager_opts) do
    if parent = manager_opts[:parent] do
      add_parent_opt(backends, parent)
    else
      backends
    end
  end

  defp add_parent_opt(backends, parent) when is_list(backends) and is_pid(parent) do
    Enum.map(backends, fn backend -> add_parent_opt(backend, parent) end)
  end

  defp add_parent_opt(backend, parent) when is_atom(backend) and is_pid(parent) do
    add_parent_opt({backend, []}, parent)
  end

  defp add_parent_opt({backend, opts}, parent)
       when is_atom(backend) and is_list(opts) and is_pid(parent) do
    {backend, Keyword.put(opts, :parent, parent)}
  end
end
