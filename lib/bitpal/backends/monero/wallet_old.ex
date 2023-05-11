# defmodule BitPal.Backend.Monero.WalletOld do
#   use GenServer
#   alias BitPal.Files
#   alias BitPalSchemas.Invoice
#   # alias BitPal.Backend.Monero.DaemonRPC
#   alias BitPal.Backend.Monero.WalletRPC
#   alias BitPal.Backend.Monero.Settings
#   require Logger
#
#   # FIXME configurable what account we should pass our payments to?
#   @account 0
#
#   # FIXME state we need to hold in a database:
#   # account_index
#   # unused subaddresses
#   # current subaddress index
#   # address associeated wath an invoice
#
#   def start_link(opts) do
#     GenServer.start_link(__MODULE__, opts, name: __MODULE__)
#   end
#
#   @spec generate_subaddress ::
#           {:ok, %{address: String.t(), address_index: non_neg_integer}} | {:error, term}
#   def generate_subaddress do
#     case WalletRPC.create_address(@account) do
#       {:ok, %{"address" => address, "address_index" => index}} ->
#         {:ok, %{address: address, address_index: index}}
#
#       err ->
#         err
#     end
#   end
#
#   # Server API
#
#   @impl true
#   def init(opts) do
#     Process.flag(:trap_exit, true)
#
#     state =
#       Enum.into(opts, %{
#         rpc_client: BitPal.RPCClient
#       })
#
#     {:ok, state, {:continue, :init}}
#   end
#
#   @impl true
#   def handle_continue(:init, state) do
#     filename = Files.wallet_file(:monero, Settings.net())
#
#     # FIXME move to address key storage
#
#     port =
#       if File.exists?(filename) do
#         open_wallet(filename)
#       else
#         generate_wallet(filename)
#       end
#
#     Port.monitor(port)
#
#     {:noreply, Map.put(state, :port, port)}
#   end
#
#   @impl true
#   def handle_info({_port, {:data, _msg}}, state) do
#     # Catches all output from port.
#     # Comment this out to see the console output of the wallet:
#     # IO.puts(msg)
#     {:noreply, state}
#   end
#
#   @impl true
#   def handle_info({:EXIT, _port, reason}, state) do
#     Logger.error("Monero wallet RPC exited! #{inspect(reason)}")
#     {:stop, reason, state}
#   end
#
#   @impl true
#   def handle_info({:DOWN, _monitor, :port, _port, reason}, state) do
#     Logger.error("Monero wallet RPC unexpectedly closed! #{inspect(reason)}")
#     {:stop, :error, state}
#   end
#
#   @impl true
#   def terminate(reason, %{port: port}) do
#     Logger.info("Closing Monero wallet #{inspect(reason)}")
#     WalletRPC.stop(port)
#     :normal
#   end
#
#   @impl true
#   def terminate(reason, _state) do
#     Logger.error("Terminating Monero wallet #{inspect(reason)}")
#     reason
#   end
#
#   defp open_wallet(filename) do
#     Logger.info("Opening Monero wallet")
#     Logger.info("  filename: #{filename}")
#     WalletRPC.open_wallet(filename)
#   end
#
#   defp generate_wallet(filename) do
#     viewkey = "1a651458fee485016e19274e3ad7cb0e7de8158e159dff9462febc91fc25410a"
#
#     address =
#       "53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru"
#
#     restore_height = 1_349_159
#
#     Logger.info("Generating new Monero wallet")
#     Logger.info("  filename: #{filename}")
#     Logger.info("  address: #{address}")
#     Logger.info("  viewkey: #{viewkey}")
#     Logger.info("  restore_height: #{restore_height}")
#
#     {fd, json_path} = Temp.open!("monero-wallet.json")
#
#     :ok =
#       IO.write(
#         fd,
#         Jason.encode!(%{
#           address: address,
#           viewkey: viewkey,
#           version: 1,
#           filename: filename,
#           scan_from_height: restore_height
#         })
#       )
#
#     :ok = File.close(fd)
#     # FIXME should cleanup temp file later
#     # File.rm(json_path)
#
#     File.mkdir_p!(Path.dirname(filename))
#     WalletRPC.generate_from_json(json_path)
#   end
#
#   # defp account_exists?(account) do
#   # end
# end
#
# # Stagenet wallet created from the cli:
# #
# # Generated new wallet: 
# # 53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru
# # View key:
# # 1a651458fee485016e19274e3ad7cb0e7de8158e159dff9462febc91fc25410a
# #
# # 0  53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru  Primary address
# #
# # seed:
# # movement five diplomat reduce purged fading biplane sadness
# # oyster fiat opacity nudged skew pairing together juggled
# # wildly bulb tinted nowhere dyslexic aching saga skew together
# #
# #
# # Old address. Mainnet?
# # address =
# #   "496YrjKKenbYS6KCfPabsJ11pTkikW79ZDDrkPDTC79CSTdCoubgh3f5BrupzBvPLWXNjjNsY8smmFDYvgVRQDsmCT5FhCU"
# #
# # viewkey = "805b4f767bdc7774a5c5ae2b3b8981c53646fff952f92de1ff749cf922e26d0f"
