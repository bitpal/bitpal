defmodule BitPal.Backend.Monero do
  @behaviour BitPal.Backend
  use GenServer
  require Logger
  alias BitPal.Backend
  alias BitPal.ExtNotificationHandler
  alias BitPal.BackendEvents
  alias BitPal.BackendStatusSupervisor
  alias BitPal.Backend.Monero.{DaemonRPC, Wallet}
  alias BitPal.ProcessRegistry

  @supervisor MoneroSupervisor
  @xmr :XMR

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: @xmr,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currency(_backend), do: @xmr

  @impl Backend
  def configure(_backend, _opts), do: :ok

  @impl Backend
  def info(backend), do: GenServer.call(backend, :get_info)

  # Server API

  @impl true
  def init(opts) do
    Registry.register(
      ProcessRegistry,
      Backend.via_tuple(@xmr),
      __MODULE__
    )

    {:ok, opts, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, opts) do
    Logger.info("Starting Monero backend")
    BackendStatusSupervisor.set_starting(@xmr)

    state =
      Enum.into(opts, %{})
      |> Map.put_new(:sync_check_interval, 1_000)
      |> Map.put_new(:daemon_check_interval, 5_000)

    {:noreply, state, {:continue, :info}}
  end

  @impl true
  def handle_continue(:info, state) do
    case DaemonRPC.get_info() do
      {:ok, info} -> {:noreply, update_daemon_info(info, state), {:continue, :init_wallet}}
      {:error, error} -> {:stop, {:shutdown, error}, state}
    end
  end

  def handle_continue(:init_wallet, state) do
    ExtNotificationHandler.subscribe("monero:tx-notify")
    ExtNotificationHandler.subscribe("monero:block-notify")
    ExtNotificationHandler.subscribe("monero:reorg-notify")

    children = [
      # DaemonRPC,
      Wallet
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: @supervisor)

    {:noreply, state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    # Generate a new subaddress for the invoice
    # Maybe with `create_address`?
    #
    # invoice = Wallet.generate_subaddress(invoice)

    {:reply, {:ok, invoice}, state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    {:reply, create_info(state), state}
  end

  @impl true
  def handle_info(:update_info, state) do
    case DaemonRPC.get_info() do
      {:ok, info} -> {:noreply, update_daemon_info(info, state)}
      {:error, error} -> {:stop, {:shutdown, error}, state}
    end
  end

  @impl true
  def handle_info({:notify, "monero:tx-notify", msg}, state) do
    IO.puts("tx seen: #{inspect(msg)}")

    # [txid] = msg

    # Lookup tx hash with `get_transfer_by_txid`
    # We could/should check for 0-conf security here
    # Otherwise the subaddress the tx is going to is should be accepted (assuming it's paid in full!)

    # address = Wallet.get_subaddress_from_txid(txid)

    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:block-notify", msg}, state) do
    IO.puts("block seen: #{inspect(msg)}")

    # Check if we have any pending invoice without a confirmation, poll them for info and see if they're conf

    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:reorg-notify", msg}, state) do
    Logger.warn("reorg detected!: #{inspect(msg)}")

    # Must check if any previously confirmed invoice is affected

    {:noreply, state}
  end

  # Internal impl

  defp update_daemon_info(info, state) do
    state
    |> update_sync(info)
    |> store_daemon_info(info)
  end

  defp update_sync(state, %{"synchronized" => true}) do
    BackendStatusSupervisor.sync_done(@xmr)
    Process.send_after(self(), :update_info, state.daemon_check_interval)
    state
  end

  defp update_sync(state, %{
         "synchronized" => false,
         "target_height" => target_height,
         "height" => height
       }) do
    BackendStatusSupervisor.set_syncing(@xmr, {height, target_height})
    Process.send_after(self(), :update_info, state.sync_check_interval)
    state
  end

  defp store_daemon_info(state, info) do
    BackendEvents.broadcast({{:backend, :info}, %{info: info, currency_id: @xmr}})
    Map.put(state, :daemon_info, info)
  end

  defp create_info(state) do
    Map.get(state, :daemon_info, %{})
  end
end
