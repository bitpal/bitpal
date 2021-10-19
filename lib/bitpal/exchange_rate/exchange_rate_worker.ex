defmodule BitPal.ExchangeRate.Worker do
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor.Result
  alias BitPal.ProcessRegistry

  @supervisor BitPal.TaskSupervisor
  @cache BitPal.ExchangeRate.Cache

  # Client API

  @spec start_worker(ExchangeRate.pair(), keyword) :: {:ok, pid} | :error
  def start_worker(pair, opts \\ []) do
    case get_worker(pair) do
      {:ok, pid} ->
        {:ok, pid}

      _ ->
        case Task.Supervisor.start_child(
               @supervisor,
               __MODULE__,
               :compute,
               [pair, opts],
               shutdown: :brutal_kill
             ) do
          {:ok, pid} -> {:ok, pid}
          {:ok, pid, _info} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          _ -> :error
        end
    end
  end

  @spec await_worker(ExchangeRate.pair() | pid) :: :ok | {:error, :timeout}
  def await_worker(pid) when is_pid(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      5_000 -> {:error, :timeout}
    end
  end

  def await_worker(pair) do
    case get_worker(pair) do
      {:ok, pid} -> await_worker(pid)
      _ -> :ok
    end
  end

  # Server API

  @spec compute(ExchangeRate.pair(), keyword) :: :ok
  def compute(pair, opts \\ []) do
    Registry.register(ProcessRegistry, via_tuple(pair), pair)

    backends = opts[:backends] || BitPalSettings.exchange_rate_backends()
    timeout = opts[:request_timeout] || BitPalSettings.exchange_rate_timeout()

    {uncached_backends, cached_results} = fetch_cached_results(backends, pair, opts)

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
    |> write_final_result(pair)
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
          case Cache.fetch(@cache, {backend.name(), pair, opts[:limit]}) do
            {:ok, results} -> {uncached_backends, [results | acc_results]}
            :error -> {[backend | uncached_backends], acc_results}
          end
        end
      )

    {uncached_backends, List.flatten(results)}
  end

  defp write_results_to_cache(results, pair, opts) do
    Enum.map(results, fn %Result{backend: backend} = result ->
      :ok = Cache.put(@cache, {backend.name(), pair, opts[:limit]}, result)
      result
    end)
  end

  @spec write_final_result(Result.t(), ExchangeRate.pair()) :: :ok
  defp write_final_result(nil, _pair), do: :ok
  defp write_final_result(res, pair), do: Cache.put(@cache, pair, res.rate)

  @spec get_worker(any) :: {:ok, pid} | {:error, :not_found}
  def get_worker(pair) do
    ProcessRegistry.get_process(via_tuple(pair))
  end

  defp via_tuple(pair) do
    ProcessRegistry.via_tuple({__MODULE__, pair})
  end
end
