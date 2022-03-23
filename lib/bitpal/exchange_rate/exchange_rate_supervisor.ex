defmodule BitPal.ExchangeRateSupervisor do
  use Supervisor
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateWorker
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  require Logger

  @sources Application.compile_env!(:bitpal, [BitPal.ExchangeRate, :sources])

  @spec sources(module) :: [%{source: module, prio: non_neg_integer}]
  def sources(name \\ __MODULE__) do
    all_workers(name)
    |> Enum.map(fn {source, pid} -> Map.put(ExchangeRateWorker.info(pid), :source, source) end)
  end

  @spec all_supported(module) :: %{Currency.id() => MapSet.t(Currency.id())}
  def all_supported(name \\ __MODULE__) do
    all_workers(name)
    |> Enum.map(fn {_source, pid} -> ExchangeRateWorker.supported(pid) end)
    |> Enum.reduce(%{}, fn map, acc ->
      Map.merge(map, acc, fn _k, v1, v2 ->
        MapSet.union(v1, v2)
      end)
    end)
  end

  def all_workers(name \\ __MODULE__) do
    name
    |> Supervisor.which_children()
    |> Enum.reduce([], fn
      {{ExchangeRateWorker, source}, pid, _worker, _params}, acc ->
        [{source, pid} | acc]

      _, acc ->
        acc
    end)
  end

  def cache_name(name \\ __MODULE__) do
    ProcessRegistry.via_tuple({name, :cache})
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    cache_name = cache_name(name)

    sources = opts[:sources] || @sources

    children = [
      {ExchangeRateCache, name: cache_name}
      | Enum.map(sources, fn {source, opts} ->
          {ExchangeRateWorker, Keyword.merge(opts, source: source, cache_name: cache_name)}
        end)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
