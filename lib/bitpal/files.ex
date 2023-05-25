defmodule BitPal.Files do
  @spec wallet_file(atom, atom) :: Path.t()
  def wallet_file(coin, net) do
    Path.join(coin_dir(coin), "#{net}-wallet")
  end

  @spec coin_dir(atom) :: Path.t()
  def coin_dir(coin) do
    Path.join(data_dir(), Atom.to_string(coin))
  end

  @spec process_monitor_path() :: Path.t()
  def process_monitor_path do
    ext_dir() |> Path.join("process_monitor.sh")
  end

  @spec notify_path() :: Path.t()
  def notify_path do
    ext_dir() |> Path.join("notify.sh")
  end

  @spec ext_dir() :: Path.t()
  def ext_dir do
    File.cwd!() |> Path.join("ext")
  end

  @spec notify_socket() :: Path.t()
  def notify_socket do
    # Must be the same as in notify.sh
    "/tmp/bitpal_notify_socket"
  end

  @spec data_dir :: Path.t()
  def data_dir do
    Application.get_env(:bitpal, :data_dir, "~/.bitpal") |> Path.expand()
  end
end
