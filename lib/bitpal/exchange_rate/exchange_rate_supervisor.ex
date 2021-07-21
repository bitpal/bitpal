defmodule BitPal.ExchangeRateSupervisor do
  use Supervisor
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRate.Worker
  alias BitPalSchemas.Currency
  require Logger

  @backend_cache BitPal.ExchangeRate.BackendCache
  @permanent_cache BitPal.ExchangeRate.PermanentCache
  @supervisor BitPal.ExhangeRate.TaskSupervisor

  defmodule Result do
    @type t :: %__MODULE__{
            score: non_neg_integer(),
            rate: ExchangeRate.t(),
            backend: module()
          }

    defstruct score: 0, rate: nil, backend: nil
  end

  # Supervision

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = [
      {Cache,
       name: @backend_cache,
       ttl_check_interval:
         opts[:ttl_check_interval] || BitPalConfig.exchange_rate_ttl_check_interval(),
       ttl: opts[:ttl] || BitPalConfig.exchange_rate_ttl()},
      {Cache, name: @permanent_cache, ttl_check_interval: false},
      {Task.Supervisor, name: @supervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Client interface

  @spec all_supported(keyword) :: %{atom => [Currency.id()]}
  def all_supported(opts \\ []) do
    backends = opts[:backends] || BitPalConfig.exchange_rate_backends()

    Enum.reduce(backends, %{}, fn backend, acc ->
      Map.merge(acc, backend.supported(), fn _key, a, b ->
        Enum.uniq(a ++ b)
      end)
    end)
  end

  @spec supported(Currency.id(), keyword) :: {:ok, list} | {:error, :not_found}
  def supported(id, opts \\ []) do
    case all_supported(opts)[id] do
      nil -> {:error, :not_found}
      x -> {:ok, x}
    end
  end

  @spec async_request(ExchangeRate.pair(), keyword) :: DynamicSupervisor.on_start_child()
  def async_request(pair, opts \\ []) do
    Worker.start_worker(pair, opts)
  end

  @spec request(ExchangeRate.pair(), keyword) :: {:ok, ExchangeRate.t()} | {:error, :not_found}
  def request(pair, opts \\ []) do
    case Cache.fetch(@permanent_cache, pair) do
      {:ok, res} ->
        {:ok, res.rate}

      :error ->
        {:ok, pid} = Worker.start_worker(pair, opts)
        Worker.await_worker(pid)

        case Cache.fetch(@permanent_cache, pair) do
          {:ok, res} ->
            {:ok, res.rate}

          :error ->
            {:error, :not_found}
        end
    end
  end

  @spec request!(ExchangeRate.pair(), keyword) :: ExchangeRate.t()
  def request!(pair, opts \\ []) do
    {:ok, rate} = request(pair, opts)
    rate
  end

  # def request_many(
end
