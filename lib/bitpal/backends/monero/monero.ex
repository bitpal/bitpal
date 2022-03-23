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
  def info(backend), do: GenServer.call(backend, :info)

  @impl Backend
  def poll_info(backend), do: GenServer.call(backend, :poll_info)

  # Server API

  @impl true
  def init(opts) do
    Registry.register(
      ProcessRegistry,
      Backend.via_tuple(@xmr),
      __MODULE__
    )

    IO.puts("starting...")

    {:ok, opts, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, _opts) do
    Logger.info("Starting Monero backend")

    BackendStatusSupervisor.set_starting(@xmr)

    ExtNotificationHandler.subscribe("monero:tx-notify")
    ExtNotificationHandler.subscribe("monero:block-notify")
    ExtNotificationHandler.subscribe("monero:reorg-notify")

    children = [
      # DaemonRPC,
      Wallet
    ]

    # IO.puts("starting...")

    Supervisor.start_link(children, strategy: :one_for_one, name: @supervisor)

    # Get version info
    # Get blockchain info

    {:noreply, %{}}
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
  def handle_call(:info, _from, state) do
    {:reply, create_info(state), state}
  end

  @impl true
  def handle_call(:poll_info, _from, state) do
    DaemonRPC.get_info() |> IO.inspect()
    DaemonRPC.get_version() |> IO.inspect()
    {:reply, :ok, state}
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

  defp create_info(state) do
    %{}
  end
end
