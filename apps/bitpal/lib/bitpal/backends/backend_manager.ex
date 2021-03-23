defmodule BitPal.BackendManager do
  use Supervisor
  alias BitPal.Backend

  @type currency() :: atom()
  @type backend_name() :: atom()
  @type backend() :: {backend_name(), pid()}

  # Client API

  # @spec start_link({BitPal.Backend, term()} | [BitPal.Backend]) :: any
  def start_link(children) do
    Supervisor.start_link(__MODULE__, children, name: __MODULE__)
  end

  @spec backends() :: [{backend(), :ok, [currency()]}]
  def backends() do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn {name, pid, _worker, [backend]} ->
      {{name, pid}, :ok, Backend.supported_currencies(backend, pid)}
    end)
  end

  @spec get_backend(backend_name()) :: {:ok, pid()} | {:error, :not_found}
  def get_backend(name) do
    backends()
    |> Enum.find_value({:error, :not_found}, fn
      {{^name, pid}, _, _} -> {:ok, pid}
      _ -> false
    end)
  end

  @spec backend_status(backend_name()) :: :ok | :not_found
  def backend_status(backend) do
    backends()
    |> Enum.find_value(:not_found, fn
      {{^backend, _}, status, _} -> status
      _ -> false
    end)
  end

  @spec currencies() :: [{currency(), :ok, backend()}]
  def currencies() do
    Enum.reduce(backends(), [], fn {id, status, currencies}, acc ->
      Enum.reduce(currencies, acc, fn currency, acc ->
        [{currency, status, id} | acc]
      end)
    end)
  end

  @spec currency_list() :: [currency()]
  def currency_list() do
    currencies()
    |> Enum.reduce([], fn {currency, _, _}, acc -> [currency | acc] end)
    |> Enum.sort()
  end

  @spec currency_status(currency()) :: :ok | :not_found
  def currency_status(currency) do
    currencies()
    |> Enum.find_value(:not_found, fn
      {^currency, status, _} -> status
      _ -> false
    end)
  end

  @spec get_currency_backend(currency()) :: {:ok, pid()} | {:error, :not_found}
  def get_currency_backend(currency) do
    backends()
    |> Enum.find(fn {_id, _status, currencies} ->
      Enum.member?(currencies, currency)
    end)
    |> get_pid()
  end

  defp get_pid({{_name, pid}, _, _}), do: {:ok, pid}
  defp get_pid(_), do: {:error, :not_found}

  # Server API

  @impl true
  def init(children) do
    Supervisor.init(children, strategy: :one_for_one)
  end
end
