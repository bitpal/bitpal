defmodule BitPal.Backend.Monero.DaemonRPC do
  import BitPal.Backend.Monero.Settings
  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_block_count(client) do
    call(client, "get_block_count")
  end

  def get_version(client) do
    call(client, "get_version")
  end

  def get_info(client) do
    call(client, "get_info")
  end

  def sync_info(client) do
    call(client, "sync_info")
  end

  # def launch_params do
  #   [
  #     System.find_executable("monerod")
  #     | daemon_executable_options()
  #   ]
  #   |> Enum.join(" ")
  # end
  #
  # def daemon_executable_options do
  #   [
  #     "--stagenet",
  #     "--reorg-notify",
  #     "#{Files.notify_path()} monero:reorg-notify %s",
  #     "--block-notify",
  #     "#{Files.notify_path()} monero:block-notify %s"
  #   ]
  # end

  # Server API

  # @impl true
  # def init(init_args) do
  #   {:ok, init_args}
  # end

  # defp async_call(method, params, task_supervisor) do
  #   from = self()
  #
  #   Task.Supervisor.async_nolink(task_supervisor, fn ->
  #     reply = call(method, params)
  #     send(from, {method, reply})
  #   end)
  # end

  defp call(client, method, params \\ %{}) do
    Logger.notice("#{client} #{method}  #{inspect(params)}")

    client.call(daemon_uri(), method, params)
  end
end
