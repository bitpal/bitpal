defmodule BitPal.ExchangeRateWorker do
  use GenServer
  alias BitPal.ExchangeRates
  alias BitPal.ProcessRegistry
  alias BitPal.RateLimiter
  alias BitPalSettings.ExchangeRateSettings

  def supported(worker) do
    GenServer.call(worker, :supported)
  end

  def rates(worker) do
    GenServer.call(worker, :rates)
  end

  def info(worker) do
    GenServer.call(worker, :info)
  end

  def set_supported(source, supported) do
    case fetch_worker(source) do
      {:ok, worker} ->
        GenServer.call(worker, {:set_supported, supported})

      _ ->
        nil
    end
  end

  def update_rates(source, rates) do
    case fetch_worker(source) do
      {:ok, worker} ->
        GenServer.call(worker, {:update_rates, rates})

      _ ->
        nil
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts) do
    id = Keyword.get(opts, :id) || Keyword.fetch!(opts, :module)

    %{
      id: {__MODULE__, id},
      restart: :permanent,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl true
  def init(opts) do
    module = Keyword.fetch!(opts, :module)
    id = Keyword.get(opts, :id, module)
    prio = Keyword.fetch!(opts, :prio)
    name = Keyword.get_lazy(opts, :name, fn -> module.name() end)

    supported_refresh_rate =
      Keyword.get(opts, :supported_refresh_rate, ExchangeRateSettings.supported_refresh_rate())

    rates_refresh_rate =
      Keyword.get(opts, :rates_refresh_rate, ExchangeRateSettings.rates_refresh_rate())

    retry_timeout = Keyword.get(opts, :retry_timeout, ExchangeRateSettings.retry_timeout())

    rate_limit_settings =
      module.rate_limit_settings()
      |> Map.put(:retry_timeout, retry_timeout)
      |> Enum.into([])

    {:ok, rate_limiter} = RateLimiter.start_link(rate_limit_settings)

    send(self(), :fetch_supported)

    Registry.register(
      ProcessRegistry,
      via_tuple(id),
      __MODULE__
    )

    state = %{
      id: id,
      module: module,
      prio: prio,
      name: name,
      rate_limiter: rate_limiter,
      supported_refresh_rate: supported_refresh_rate,
      rates_refresh_rate: rates_refresh_rate,
      supported: %{},
      rates: %{}
    }

    {:ok, state}
  end

  defp via_tuple(id) do
    ProcessRegistry.via_tuple({__MODULE__, id})
  end

  @impl true
  def handle_info(:update_rates, state) do
    fiat_to_update = ExchangeRateSettings.fiat_to_update()
    crypto_to_update = ExchangeRateSettings.crypto_to_update()

    case state.module.request_type() do
      :pair ->
        for crypto_id <- crypto_to_update do
          if supported = Map.get(state.supported, crypto_id) do
            for fiat_id <- fiat_to_update do
              if MapSet.member?(supported, fiat_id) do
                send(self(), {:update, pair: {crypto_id, fiat_id}})
              end
            end
          end
        end

      :base ->
        for crypto_id <- crypto_to_update do
          if Map.has_key?(state.supported, crypto_id) do
            send(self(), {:update, base: crypto_id})
          end
        end

      :multi ->
        crypto = Enum.filter(crypto_to_update, fn id -> Map.has_key?(state.supported, id) end)

        send(self(), {:update, base: crypto, quote: fiat_to_update})
    end

    Process.send_after(self(), :update_rates, state.rates_refresh_rate)

    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_supported, state) do
    RateLimiter.make_request(
      state.rate_limiter,
      {state.module, :supported, []},
      {__MODULE__, :set_supported, [state.module]}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:update, opts}, state) do
    RateLimiter.make_request(
      state.rate_limiter,
      {state.module, :rates, [opts]},
      {__MODULE__, :update_rates, [state.module]}
    )

    {:noreply, state}
  end

  @impl true
  def handle_call({:set_supported, supported}, _from, state) do
    Process.send_after(self(), :fetch_supported, state.supported_refresh_rate)

    # This is the first time, let's launch rate updates
    if state.supported == %{} && !Enum.empty?(supported) do
      send(self(), :update_rates)
    end

    state =
      state
      |> Map.put(:supported, supported)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_rates, updated_rates}, _from, state) do
    ExchangeRates.update_exchange_rates(%{
      rates: updated_rates,
      source: state.id,
      prio: state.prio
    })

    new_rates =
      Map.merge(state.rates, updated_rates, fn _k, v1, v2 ->
        Map.merge(v1, v2)
      end)

    state =
      state
      |> Map.put(:rates, new_rates)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:supported, _from, state) do
    {:reply, state.supported, state}
  end

  @impl true
  def handle_call(:rates, _from, state) do
    {:reply, state.rates, state}
  end

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, %{prio: state.prio, name: state.name}, state}
  end

  @spec fetch_worker(term) :: {:ok, pid} | {:error, :not_found}
  def fetch_worker(id) do
    ProcessRegistry.get_process(via_tuple(id))
  end
end
