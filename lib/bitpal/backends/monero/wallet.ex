defmodule BitPal.Backend.Monero.Wallet do
  use GenServer
  require Logger
  alias BitPal.Files
  alias BitPal.Invoice
  alias BitPal.Backend.Monero.DaemonRPC
  alias BitPal.Backend.Monero.WalletRPC

  # FIXME configurable what account we should pass our payments to?
  @account 0

  # FIXME state we need to hold in a database:
  # account_index
  # unused subaddresses
  # current subaddress index
  # address associeated wath an invoice

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec register_address(Invoice.t()) :: Invoice.t()
  def register_address(invoice) do
    # First check if there's an address associated with the invoice
    if false do
      invoice
    else
      {:ok,
       %{
         "address" => address,
         "address_index" => address_index
       }} = WalletRPC.create_address(@account)

      # FIXME track address index in db

      %{invoice | address: address}
    end
  end

  # Server API

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)

    filename = Files.wallet_file(:monero)

    # FIXME move to address key storage
    address =
      "496YrjKKenbYS6KCfPabsJ11pTkikW79ZDDrkPDTC79CSTdCoubgh3f5BrupzBvPLWXNjjNsY8smmFDYvgVRQDsmCT5FhCU"

    viewkey = "805b4f767bdc7774a5c5ae2b3b8981c53646fff952f92de1ff749cf922e26d0f"

    port =
      if File.exists?(filename) do
        open_wallet(filename)
      else
        generate_wallet(filename, address, viewkey)
      end

    Port.monitor(port)

    {:ok, %{port: port}}
  end

  @impl true
  def handle_info({_port, {:data, _msg}}, state) do
    # Silence output from daemon
    # IO.puts(msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _monitor, :port, _port, _reason}, state) do
    Logger.error("Monero wallet RPC unexpectedly closed!")
    {:stop, :error, state}
  end

  @impl true
  def terminate(reason, %{port: port}) do
    Logger.info("Closing Monero wallet #{inspect(reason)}")
    WalletRPC.stop(port)
    :normal
  end

  defp open_wallet(filename) do
    Logger.info("Opening Monero wallet")
    Logger.info("  filename: #{filename}")
    WalletRPC.open_wallet(filename)
  end

  defp generate_wallet(filename, address, viewkey) do
    Logger.info("Generating new Monero wallet")
    Logger.info("  filename: #{filename}")
    Logger.info("  address: #{address}")
    Logger.info("  viewkey: #{viewkey}")

    {fd, json_path} = Temp.open!("monero-wallet.json")

    :ok =
      IO.write(
        fd,
        Jason.encode!(%{address: address, viewkey: viewkey, version: 1, filename: filename})
      )

    :ok = File.close(fd)
    File.rm(json_path)

    File.mkdir_p!(Path.dirname(filename))
    WalletRPC.generate_from_json(json_path)
  end

  # defp account_exists?(account) do
  # end
end
