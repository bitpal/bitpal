defmodule BitPal.Files do
  alias BitPalSchemas.Store

  @spec wallet_file(atom, atom) :: Path.t()
  def wallet_file(coin, net) do
    Path.join(coin_dir(coin), wallet_filename(net))
  end

  @spec wallet_file(Store.id(), atom, atom) :: Path.t()
  def wallet_file(store_id, coin, net) do
    Path.join(coin_dir(coin), wallet_filename(store_id, net))
  end

  @spec wallet_filename(atom) :: Path.t()
  def wallet_filename(net) do
    "#{net}-wallet"
  end

  @spec wallet_filename(Store.id(), atom) :: Path.t()
  def wallet_filename(store_id, net) do
    "#{store_id}-#{net}-wallet"
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
