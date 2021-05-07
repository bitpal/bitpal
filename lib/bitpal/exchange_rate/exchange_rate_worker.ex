defmodule BitPal.ExchangeRate.Worker do
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor
  alias BitPal.ExchangeRateSupervisor.Result
  alias BitPal.ProcessRegistry

  @backend_cache BitPal.ExchangeRate.BackendCache
  @permanent_cache BitPal.ExchangeRate.PermanentCache
  @supervisor BitPal.ExhangeRate.TaskSupervisor

  # Client API

  def start_worker(pair, opts \\ []) do
    case get_worker(pair) do
      {:ok, pid} ->
        {:already_started, pid}

      _ ->
        Task.Supervisor.start_child(
          @supervisor,
          __MODULE__,
          :compute,
          [pair, opts],
          shutdown: :brutal_kill
        )
    end
  end

  def await_worker(pair, _opts \\ []) do
    case get_worker(pair) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        after
          5_000 -> {:error, :timeout}
        end

      _ ->
        :ok
    end
  end

  # Server API

  @spec compute(ExchangeRate.pair(), keyword) :: :ok
  def compute(pair, opts \\ []) do
    Registry.register(ProcessRegistry, via_tuple(pair), pair)

    backends = opts[:backends] || Application.fetch_env!(:bitpal, BitPal.ExchangeRate)[:backends]
    timeout = opts[:timeout] || 2_000

    {uncached_backends, cached_results} = fetch_cached_results(backends, pair, opts)

    res =
      uncached_backends
      |> Enum.map(&async_compute(&1, pair, opts))
      |> Task.yield_many(timeout)
      |> Enum.map(fn
        {_, {:ok, res}} -> res
        {task, _} -> Task.shutdown(task, :brutal_kill)
      end)
      |> Enum.flat_map(fn
        {:ok, res} -> [res]
        _ -> []
      end)
      |> write_results_to_cache(pair, opts)
      |> Kernel.++(cached_results)
      |> Enum.sort(&(&1.score >= &2.score))
      |> List.first()
      |> get_or_write_to_permanent_cache(pair)

    case res do
      {:ok, res} ->
        :ok = ExchangeRateSupervisor.broadcast(pair, res)

      _ ->
        :ok
    end
  end

  # Internal

  defp async_compute(backend, pair, opts) do
    Task.Supervisor.async_nolink(
      @supervisor,
      BitPal.ExchangeRate.Backend,
      :compute,
      [backend, pair, opts],
      shutdown: :brutal_kill
    )
  end

  defp fetch_cached_results(backends, pair, opts) do
    {uncached_backends, results} =
      Enum.reduce(
        backends,
        {[], []},
        fn backend, {uncached_backends, acc_results} ->
          case Cache.fetch(@backend_cache, {backend.name(), pair, opts[:limit]}) do
            {:ok, results} -> {uncached_backends, [results | acc_results]}
            :error -> {[backend | uncached_backends], acc_results}
          end
        end
      )

    {uncached_backends, List.flatten(results)}
  end

  defp write_results_to_cache(results, pair, opts) do
    Enum.map(results, fn %Result{backend: backend} = result ->
      :ok = Cache.put(@backend_cache, {backend.name(), pair, opts[:limit]}, result)

      result
    end)
  end

  @spec get_or_write_to_permanent_cache(Result.t(), ExchangeRate.pair()) ::
          {:ok, Result.t()} | {:error, :not_found}
  defp get_or_write_to_permanent_cache(nil, pair) do
    case Cache.fetch(@permanent_cache, pair) do
      res = {:ok, _} -> res
      :error -> {:error, :not_found}
    end
  end

  defp get_or_write_to_permanent_cache(res, pair) do
    :ok = Cache.put(@permanent_cache, pair, res)
    {:ok, res}
  end

  @spec get_worker(any) :: {:ok, pid} | {:error, :not_found}
  defp get_worker(pair) do
    ProcessRegistry.get_process(via_tuple(pair))
  end

  defp via_tuple(pair) do
    ProcessRegistry.via_tuple({__MODULE__, pair})
  end
end
