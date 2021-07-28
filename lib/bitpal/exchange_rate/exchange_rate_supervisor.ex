defmodule BitPal.ExchangeRateSupervisor do
  use Supervisor
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRate.Worker
  alias BitPalSchemas.Currency
  require Logger

  @cache BitPal.ExchangeRate.Cache

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
       name: @cache,
       ttl_check_interval:
         opts[:ttl_check_interval] || BitPalConfig.exchange_rate_ttl_check_interval(),
       ttl: opts[:ttl] || BitPalConfig.exchange_rate_ttl()}
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

  @spec fetch!(ExchangeRate.pair(), keyword) :: ExchangeRate.t() | nil
  def fetch!(pair, opts \\ []) do
    request(pair, opts)
    await_request!(pair)
  end

  @spec request(ExchangeRate.pair(), keyword) :: {:cached, ExchangeRate.t()} | :updating
  def request(pair, opts \\ []) do
    case Cache.fetch(@cache, pair) do
      {:ok, rate} ->
        {:cached, rate}

      :error ->
        {:ok, _pid} = Worker.start_worker(pair, opts)
        :updating
    end
  end

  @spec await_request!(ExchangeRate.pair()) :: ExchangeRate.t() | nil
  def await_request!(pair) do
    :ok = Worker.await_worker(pair)
    Cache.get(@cache, pair)
  end
end
