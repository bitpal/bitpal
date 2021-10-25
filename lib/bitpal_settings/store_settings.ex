defmodule BitPalSettings.StoreSettings do
  import Ecto.Query
  import Ecto.Changeset
  alias BitPalSchemas.Store
  alias BitPalSchemas.Currency
  alias BitPalSchemas.CurrencySettings
  alias BitPal.Repo

  # Currency settings

  @spec get_xpub(Store.id(), Currency.id()) :: String.t() | nil
  def get_xpub(store_id, currency_id) do
    get(store_id, currency_id, :xpub)
  end

  @spec set_xpub(Store.id(), Currency.id(), String.t()) ::
          {:ok, CurrencySettings.t()} | {:error, :not_found}
  def set_xpub(store_id, currency_id, xpub) do
    set(store_id, currency_id, :xpub, xpub)
  end

  @spec get_required_confirmations(Store.id(), Currency.id()) :: non_neg_integer
  def get_required_confirmations(store_id, currency_id) do
    get(store_id, currency_id, :required_confirmations)
  end

  @spec set_required_confirmations(Store.id(), Currency.id(), non_neg_integer) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def set_required_confirmations(store_id, currency_id, confs) do
    set(store_id, currency_id, :required_confirmations, confs)
  end

  @spec get_double_spend_timeout(Store.id(), Currency.id()) :: non_neg_integer
  def get_double_spend_timeout(store_id, currency_id) do
    get(store_id, currency_id, :double_spend_timeout)
  end

  @spec set_double_spend_timeout(Store.id(), Currency.id(), non_neg_integer) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def set_double_spend_timeout(store_id, currency_id, timeout) do
    set(store_id, currency_id, :double_spend_timeout, timeout)
  end

  @spec get_currency_settings(Store.id(), Currency.id()) :: CurrencySettings.t() | nil
  def get_currency_settings(store_id, currency_id) do
    currency_settings_query(store_id, currency_id)
    |> Repo.one()
  end

  defp currency_settings_query(store_id, currency_id) do
    from(x in CurrencySettings,
      where: x.store_id == ^store_id and x.currency_id == ^Atom.to_string(currency_id)
    )
  end

  def default_currency_settings() do
    %CurrencySettings{
      xpub: Application.get_env(:bitpal, :xpub),
      required_confirmations: Application.get_env(:bitpal, :required_confirmations),
      double_spend_timeout: Application.get_env(:bitpal, :double_spend_timeout)
    }
  end

  @spec get(Store.id(), Currency.id(), atom) :: any()
  defp get(store_id, currency_id, key) do
    from(x in currency_settings_query(store_id, currency_id),
      select: field(x, ^key)
    )
    |> Repo.one() || Application.get_env(:bitpal, key)
  end

  defp set(store_id, currency_id, key, value) do
    case get_currency_settings(store_id, currency_id) do
      nil -> %CurrencySettings{currency_id: currency_id, store_id: store_id}
      settings -> settings
    end
    |> change(%{key => value})
    |> foreign_key_constraint(:currency_id)
    |> foreign_key_constraint(:store_id)
    |> Repo.insert_or_update()
  end
end
