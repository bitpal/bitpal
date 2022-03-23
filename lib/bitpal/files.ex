defmodule BitPal.Files do
  # @spec open_tmp_file(Temp.options()) :: {File.io_device(), Path.t()}
  # @spec open!(options, pid | nil) :: Path.t | {File.io_device, Path.t} | no_return
  # def open_tmp_file(opts \\ nil) do
  #   Temp.open!(opts)
  # end
  #
  # @spec tmp_file(Temp.options()) :: Path.t()
  # def tmp_file(opts \\ nil) do
  #   Temp.path!(opts)
  # end
  #
  # @spec tmp_dir(Temp.options()) :: Path.t()
  # def tmp_dir(opts \\ nil) do
  #   Temp.mkdir!(opts)
  # end

  @spec wallet_file(atom) :: Path.t()
  def wallet_file(coin) do
    Path.join(coin_dir(coin), "wallet")
  end

  @spec coin_dir(atom) :: Path.t()
  def coin_dir(coin) do
    Path.join(data_dir(), Atom.to_string(coin))
  end

  @spec process_monitor_path() :: Path.t()
  def process_monitor_path() do
    ext_dir() |> Path.join("process_monitor.sh")
  end

  @spec notify_path() :: Path.t()
  def notify_path() do
    ext_dir() |> Path.join("notify.sh")
  end

  @spec ext_dir() :: Path.t()
  def ext_dir() do
    File.cwd!() |> Path.join("ext")
  end

  @spec notify_socket() :: Path.t()
  def notify_socket() do
    # Must be the same as in notify.sh
    "/tmp/bitpal_notify_socket"
    # Path.join(data_dir(), "notify_socket")
  end

  @spec data_dir :: Path.t()
  def data_dir() do
    Application.get_env(:bitpal, :data_dir, "~/.bitpal") |> Path.expand()
  end
end
