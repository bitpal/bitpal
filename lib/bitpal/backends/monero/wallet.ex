defmodule BitPal.Backend.Monero.Wallet do
  import BitPal.Backend.Monero.Settings
  alias BitPal.Files
  require Logger

  # FIXME renome rpc to rpc

  @rpc_password ""

  @doc """
  A child spec for running monero-wallet-rpc under supervision.
  It will open an existing wallet or create one if it doesn't exist.
  """
  def executable_child_spec do
    {MuonTrap.Daemon, [executable(), executable_options()]}
  end

  defp executable do
    System.find_executable("monero-wallet-rpc")
  end

  defp executable_options do
    wallet_file = Files.wallet_file(:monero, net())

    if File.exists?(wallet_file) do
      open_wallet_args(wallet_file)
    else
      create_wallet_args(wallet_file)
    end
  end

  defp open_wallet_args(wallet_file) do
    Logger.info("Opening Monero wallet")
    Logger.info("  filename: #{wallet_file}")

    ["--wallet-file", wallet_file] ++ common_options()
  end

  defp create_wallet_args(wallet_file) do
    viewkey = "1a651458fee485016e19274e3ad7cb0e7de8158e159dff9462febc91fc25410a"

    address =
      "53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru"

    restore_height = 1_349_159

    # Use --generate-from-json to launch wallet-rpc with a new wallet file
    {fd, json_file} = Temp.open!("monero-wallet.json")

    :ok =
      IO.write(
        fd,
        Jason.encode!(%{
          address: address,
          viewkey: viewkey,
          version: 1,
          filename: wallet_file,
          scan_from_height: restore_height
        })
      )

    :ok = File.close(fd)
    # FIXME should cleanup temp file later
    # File.rm(json_path)

    Logger.info("Generating new Monero wallet")
    Logger.info("  filename: #{wallet_file}")
    Logger.info("  address: #{address}")
    Logger.info("  viewkey: #{viewkey}")
    Logger.info("  restore_height: #{restore_height}")

    File.mkdir_p!(Path.dirname(wallet_file))
    ["--generate-from-json", json_file] ++ common_options()
  end

  defp common_options do
    [
      "--stagenet",
      "--daemon-address",
      "#{daemon_ip()}:#{daemon_port()}",
      "--rpc-bind-port",
      "#{wallet_port()}",
      "--disable-rpc-login",
      "--log-file",
      "/var/log/monero/bitpal.log",
      "--log-level",
      "2",
      "--password",
      @rpc_password,
      "--trusted-daemon",
      # "--non-interactive",
      "--tx-notify",
      "#{Files.notify_path()} monero:tx-notify %s"
    ]
  end
end

# Not sure if it's better to use MuonTrap or Port:
# @spec stop(module, port) :: true
# def stop(client, port) do
#   close_wallet(client)
#   Port.close(port)
# end

# defp start(args) do
#   Port.open({:spawn_executable, Files.process_monitor_path()}, [
#     :binary,
#     args:
#       [
#         System.find_executable("monero-wallet-rpc")
#         | wallet_executable_options()
#       ] ++ args
#   ])
# end
