defmodule BitPal.Backend.Monero.WalletSupervisor do
  use DynamicSupervisor
  alias BitPalSettings.StoreSettings
  alias BitPal.Backend.Monero.Wallet
  alias BitPal.ProcessRegistry

  def ensure_wallet(store_id, opts) do
    case fetch_wallet(store_id) do
      handler = {:ok, _} -> handler
      {:error, _} -> start_wallet(store_id, opts)
    end
  end

  def fetch_wallet(store_id) do
    ProcessRegistry.get_process(Wallet.via_tuple(store_id))
  end

  defp start_wallet(store_id, opts) do
    case StoreSettings.fetch_address_key(store_id, :XMR) do
      {:ok, key} ->
        DynamicSupervisor.start_child(
          __MODULE__,
          {Wallet, Keyword.merge(opts, store_id: store_id, address_key: key)}
        )

      {:error, _} ->
        {:error, :address_key_not_assigned}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      restart: :transient,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    if log_level = opts[:log_level] do
      Logger.put_process_level(self(), log_level)
    end

    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
