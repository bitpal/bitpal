defmodule BitPal.ExchangeRateSupervisor do
  use Supervisor
  alias BitPal.ExchangeRateWorker
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

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    sources = opts[:sources] || @sources

    children =
      Enum.map(sources, fn {module, opts} ->
        args =
          opts
          |> Map.new()
          |> Map.put_new(:module, module)
          |> Enum.into([])

        {ExchangeRateWorker, args}
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
