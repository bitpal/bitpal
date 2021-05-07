defmodule BitPal.ExchangeRateSupervisor do
  use Supervisor
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRate.Worker
  alias BitPal.RuntimeStorage
  alias Phoenix.PubSub
  require Logger

  @pubsub BitPal.PubSub
  @backend_cache BitPal.ExchangeRate.BackendCache
  @permanent_cache BitPal.ExchangeRate.PermanentCache
  @supervisor BitPal.ExhangeRate.TaskSupervisor

  defmodule Result do
    @type t :: %__MODULE__{
            score: non_neg_integer(),
            rate: Decimal.t(),
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
      {Cache, name: @backend_cache, clear_interval: opts[:clear_interval]},
      {RuntimeStorage, name: @permanent_cache},
      {Task.Supervisor, name: @supervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Client interface

  @spec async_request(ExchangeRate.pair(), keyword) :: DynamicSupervisor.on_start_child()
  def async_request(pair, opts \\ []) do
    Worker.start_worker(pair, opts)
  end

  @spec request(ExchangeRate.pair(), keyword) :: {:ok, Decimal.t()} | {:error, term}
  def request(pair, opts \\ []) do
    case Cache.fetch(@permanent_cache, pair) do
      {:ok, res} ->
        {:ok, res.rate}

      :error ->
        Worker.start_worker(pair, opts)
        Worker.await_worker(pair, opts)

        case Cache.fetch(@permanent_cache, pair) do
          {:ok, res} ->
            {:ok, res.rate}

          :error ->
            {:error, :not_found}
        end
    end
  end

  @spec require!(ExchangeRate.pair(), keyword) :: Decimal.t()
  def require!(pair, opts \\ []) do
    {:ok, rate} = request(pair, opts)
    rate
  end

  @spec subscribe(ExchangeRate.pair()) :: :ok
  def subscribe(pair, opts \\ []) do
    :ok = PubSub.subscribe(@pubsub, topic(pair))
    async_request(pair, opts)
    :ok
  end

  @spec unsubscribe(ExchangeRate.pair()) :: :ok
  def unsubscribe(pair) do
    PubSub.unsubscribe(@pubsub, topic(pair))
  end

  @spec broadcast(ExchangeRate.pair(), Result.t()) :: :ok | {:error, term}
  def broadcast(pair, res) do
    PubSub.broadcast(@pubsub, topic(pair), {:exchange_rate, pair, res.rate})
  end

  defp topic({from, to}) do
    Atom.to_string(__MODULE__) <> Atom.to_string(from) <> Atom.to_string(to)
  end
end
