defmodule BitPal.BackendManager do
  use Supervisor
  alias BitPal.Backend
  alias BitPal.BackendEvent
  alias BitPal.Invoice

  @type backend_name() :: atom()

  # Client API

  @spec start_link([Supervisor.child_spec()]) :: Supervisor.on_start()
  def start_link(children) do
    Supervisor.start_link(__MODULE__, children, name: __MODULE__)
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

  @spec backends() :: [{backend_name(), Backend.backend_ref(), :ok, [Request.currency()]}]
  def backends() do
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

  @spec currencies() :: [{Request.currency(), :ok, Backend.backend_ref()}]
  def currencies() do
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

  @spec currency_list() :: [Request.currency()]
  def currency_list() do
    currencies()
    |> Enum.reduce([], fn {currency, _, _}, acc -> [currency | acc] end)
    |> Enum.sort()
  end

  @spec currency_status(Request.currency()) :: :ok | :not_found
  def currency_status(currency) do
    currencies()
    |> Enum.find_value(:not_found, fn
      {^currency, status, _} -> status
      _ -> false
    end)
  end

  @spec get_currency_backend(Request.currency()) ::
          {:ok, Backend.backend_ref()} | {:error, :not_found}
  def get_currency_backend(currency) do
    currencies()
    |> Enum.find_value({:error, :not_found}, fn
      {^currency, _, ref} -> {:ok, ref}
      _ -> false
    end)
  end

  # Server API

  @impl true
  def init(children) do
    Supervisor.init(children, strategy: :one_for_one)
  end
end
