defmodule BitPal.BackendManager do
  use Supervisor
  alias BitPal.Backend
  alias BitPal.BackendEvent
  alias BitPal.Invoice

  @type backend_spec() :: Supervisor.child_spec()
  @type backend_name() :: atom()

  # Client API

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec track(Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def track(invoice) do
    BackendEvent.subscribe(invoice)
    register(invoice)
  end

  @spec register(Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register(invoice) do
    case get_currency_backend(invoice.currency) do
      {:ok, ref} -> {:ok, Backend.register(ref, invoice)}
      {:error, _} = _error -> {:error, :backend_not_found}
    end
  end

  @spec backends() :: [{backend_name(), Backend.backend_ref(), :ok, [Invoice.currency()]}]
  def backends do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn {name, pid, _worker, [backend]} ->
      ref = {pid, backend}
      {name, ref, :ok}
    end)
  end

  @spec get_backend(backend_name()) :: {:ok, Backend.backend_ref()} | {:error, :not_found}
  def get_backend(name) do
    backends()
    |> Enum.find_value({:error, :not_found}, fn
      {^name, ref, _} -> {:ok, ref}
      _ -> false
    end)
  end

  @spec backend_status(backend_name()) :: :ok | :not_found
  def backend_status(name) do
    backends()
    |> Enum.find_value(:not_found, fn
      {^name, _, status} -> status
      _ -> false
    end)
  end

  @spec currencies() :: [{Invoice.currency(), :ok, Backend.backend_ref()}]
  def currencies do
    backends()
    |> Enum.map(fn {_name, ref, status} ->
      {ref, status, Backend.supported_currencies(ref)}
    end)
    |> Enum.reduce([], fn {ref, status, currencies}, acc ->
      Enum.reduce(currencies, acc, fn currency, acc ->
        [{currency, status, ref} | acc]
      end)
    end)
  end

  @spec currency_list() :: [Invoice.currency()]
  def currency_list do
    currencies()
    |> Enum.reduce([], fn {currency, _, _}, acc -> [currency | acc] end)
    |> Enum.sort()
  end

  @spec currency_status(Invoice.currency()) :: :ok | :not_found
  def currency_status(currency) do
    currencies()
    |> Enum.find_value(:not_found, fn
      {^currency, status, _} -> status
      _ -> false
    end)
  end

  @spec get_currency_backend(Invoice.currency()) ::
          {:ok, Backend.backend_ref()} | {:error, :not_found}
  def get_currency_backend(currency) do
    currencies()
    |> Enum.find_value({:error, :not_found}, fn
      {^currency, _, ref} -> {:ok, ref}
      _ -> false
    end)
  end

  @spec configure(backends: backend_spec()) :: :ok
  def configure(opts) do
    if backends = opts[:backends] do
      to_keep =
        backends
        |> Enum.map(&start_or_update_backend/1)
        |> Enum.reduce(%{}, fn pid, acc -> Map.put(acc, pid, true) end)

      Supervisor.which_children(__MODULE__)
      |> Enum.each(fn {child_id, pid, _, _} ->
        if !Map.has_key?(to_keep, pid) do
          :ok = Supervisor.terminate_child(__MODULE__, child_id)
          # Also removes the child specification, makes it all cleaner and
          # easier to reason about.
          :ok = Supervisor.delete_child(__MODULE__, child_id)
        end
      end)
    end
  end

  defp start_or_update_backend(spec = {backend, opts}) do
    case Supervisor.start_child(__MODULE__, spec) do
      {:error, {:already_started, pid}} when is_pid(pid) ->
        Backend.configure({pid, backend}, opts)
        pid

      {:ok, pid} when is_pid(pid) ->
        pid
    end
  end

  defp start_or_update_backend(backend) when is_atom(backend) do
    start_or_update_backend({backend, []})
  end

  # Server API

  @impl true
  def init(opts) do
    children = opts[:backends] || Application.fetch_env!(:bitpal, :backends)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
