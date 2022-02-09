defmodule BitPal.BackendStatusManager do
  use GenServer
  alias BitPal.Backend
  alias BitPal.BackendEvents
  alias Ecto.Adapters.SQL.Sandbox

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec status(term) :: Backend.backend_status()
  def status(server) do
    GenServer.call(server, :status)
  end

  def ready(server) do
    change(server, :ready)
  end

  def ready_if_syncing_or_recovering(server) do
    GenServer.call(server, :ready_if_syncing_or_recovering)
  end

  def recovering(server, processed_height, target_height) do
    change(server, {:recovering, processed_height, target_height})
  end

  def syncing(server, progress) do
    change(server, {:syncing, progress})
  end

  def error(server, error) do
    change(server, {:error, error})
  end

  def stopped(server) do
    change(server, :stopped)
  end

  @spec change(term, Backend.backend_status()) :: :ok
  defp change(server, new_status) do
    GenServer.call(server, {:change, new_status})
  end

  @impl true
  def init(opts) do
    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    {:ok,
     %{
       status: opts[:status] || :initializing,
       currency_id: Keyword.fetch!(opts, :currency_id),
       rate_limit: opts[:rate_limit] || 1_000
     }}
  end

  @impl true
  def handle_call(:status, _, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(
        {:change, new_status = {:recovering, _, _}},
        _,
        state = %{status: {:recovering, _, _}}
      ) do
    {:reply, :ok, rate_limited_change_status(state, new_status)}
  end

  @impl true
  def handle_call(
        {:change, new_status = {:syncing, _, _}},
        _,
        state = %{status: {:syncing, _, _}}
      ) do
    {:reply, :ok, rate_limited_change_status(state, new_status)}
  end

  @impl true
  def handle_call({:change, status}, _, state = %{status: status}) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:change, new_status}, _, state) do
    {:reply, :ok, change_status(state, new_status)}
  end

  @impl true
  def handle_call(:ready_if_syncing_or_recovering, _, state) do
    state =
      case state.status do
        {:syncing, _} ->
          change_status(state, :ready)

        {:recovering, _, _} ->
          change_status(state, :ready)

        _ ->
          state
      end

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
    BackendEvents.broadcast({{:backend, :status}, %{status: status, currency_id: currency_id}})
    state
  end

  defp rate_limited_broadcast(state = %{rate_limited_broadcast: true}) do
    # We're already waiting to broadcast, do nothing.
    state
  end

  defp rate_limited_broadcast(state) do
    # Queue a new broadcast.
    Process.send_after(self(), :rate_limited_broadcast, state.rate_limit)
    Map.put(state, :rate_limited_broadcast, true)
  end
end
