defmodule BitPal.ExchangeRate do
  use Supervisor
  alias BitPal.ExchangeRate.Cache
  alias BitPal.ExchangeRate.Worker
  alias Phoenix.PubSub
  require Logger

  @type pair :: {atom, atom}

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
      {Cache, [name: @backend_cache, clear_interval: opts[:clear_interval]]},
      {Cache, [name: @permanent_cache, clear_interval: :never]},
      {Task.Supervisor, name: @supervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Client interface

  @spec async_request(pair, keyword) :: DynamicSupervisor.on_start_child()
  def async_request(pair, opts \\ []) do
    Worker.start_worker(pair, opts)
  end

  @spec request(pair, keyword) :: {:ok, Decimal.t()} | {:error, term}
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

  @spec require!(pair, keyword) :: Decimal.t()
  def require!(pair, opts \\ []) do
    {:ok, rate} = request(pair, opts)
    rate
  end

  @spec subscribe(pair) :: :ok
  def subscribe(pair, opts \\ []) do
    :ok = PubSub.subscribe(@pubsub, topic(pair))
    async_request(pair, opts)
    :ok
  end

  @spec unsubscribe(pair) :: :ok
  def unsubscribe(pair) do
    PubSub.unsubscribe(@pubsub, topic(pair))
  end

  @spec broadcast(pair, Result.t()) :: :ok | {:error, term}
  def broadcast(pair, res) do
    PubSub.broadcast(@pubsub, topic(pair), {:exchange_rate, pair, res.rate})
  end

  defp topic({from, to}) do
    Atom.to_string(__MODULE__) <> Atom.to_string(from) <> Atom.to_string(to)
  end
end
