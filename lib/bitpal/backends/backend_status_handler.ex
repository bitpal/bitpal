defmodule BitPal.BackendStatusHandler do
  use GenServer
  alias BitPal.BackendEvents
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  alias BitPalSettings.BackendSettings
  alias Ecto.Adapters.SQL.Sandbox

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts) do
    currency_id = Keyword.fetch!(opts, :currency_id)

    %{
      id: currency_id,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  def status(handler) do
    GenServer.call(handler, :get_status)
  end

  def set_status(handler, status) do
    GenServer.call(handler, {:set_status, status})
  end

  def sync_done(handler) do
    GenServer.call(handler, :sync_done)
  end

  def configure(handler, opts) do
    GenServer.call(handler, {:configure, opts})
  end

  def allow_parent(handler, parent) do
    GenServer.call(handler, {:allow_parent, parent})
  end

  @impl true
  def init(opts) do
    currency_id = Keyword.fetch!(opts, :currency_id)
    Registry.register(ProcessRegistry, via_tuple(currency_id), currency_id)

    {:ok,
     %{
       status: opts[:status] || :unknown,
       currency_id: currency_id,
       rate_limit: opts[:rate_limit] || 1_000
     }}
  end

  @impl true
  def handle_call(:get_status, _, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(
        {:set_status, new_status = {:recovering, _}},
        _,
        state = %{status: {:recovering, _}}
      ) do
    {:reply, :ok, rate_limited_change_status(state, new_status)}
  end

  @impl true
  def handle_call(
        {:set_status, new_status = {:syncing, _}},
        _,
        state = %{status: {:syncing, _}}
      ) do
    {:reply, :ok, rate_limited_change_status(state, new_status)}
  end

  @impl true
  def handle_call({:set_status, status}, _, state = %{status: status}) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_status, new_status}, _, state) do
    {:reply, :ok, change_status(state, new_status)}
  end

  @impl true
  def handle_call(:sync_done, _, state) do
    state =
      case state.status do
        :starting ->
          change_status(state, :ready)

        {:syncing, _} ->
          change_status(state, :ready)

        {:recovering, _} ->
          change_status(state, :ready)

        _ ->
          state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:configure, opts}, _, state) do
    state = Map.merge(state, Map.take(opts, [:rate_limit]))
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:allow_parent, parent}, _, state) do
    Sandbox.allow(BitPal.Repo, parent, self())
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:rate_limited_broadcast, state) do
    state =
      state
      |> Map.delete(:rate_limited_broadcast)
      |> broadcast()

    {:noreply, state}
  end

  defp change_status(state, new_status) do
    state
    |> Map.put(:status, new_status)
    |> broadcast()
  end

  defp rate_limited_change_status(state, new_status) do
    state
    |> Map.put(:status, new_status)
    |> rate_limited_broadcast()
  end

  defp broadcast(state = %{status: status, currency_id: currency_id}) do
    if broadcast?(status, currency_id) do
      BackendEvents.broadcast({{:backend, :status}, %{status: status, currency_id: currency_id}})
    end

    state
  end

  # Workaround to prevent :starting messages when the manager is starting up for aLready
  # disabled backends.
  defp broadcast?(:starting, currency_id), do: BackendSettings.is_enabled(currency_id)

  defp broadcast?(_, _), do: true

  defp rate_limited_broadcast(state = %{rate_limited_broadcast: true}) do
    # We're already waiting to broadcast, do nothing.
    state
  end

  defp rate_limited_broadcast(state) do
    # Queue a new broadcast.
    Process.send_after(self(), :rate_limited_broadcast, state.rate_limit)
    Map.put(state, :rate_limited_broadcast, true)
  end

  @spec via_tuple(Currency.id()) :: {:via, Registry, any}
  def via_tuple(currency_id) do
    ProcessRegistry.via_tuple({__MODULE__, currency_id})
  end
end
