defmodule BitPalSettings.StoreSettings do
  import Ecto.Query
  import Ecto.Changeset
  alias BitPalSchemas.Address
  alias BitPalSchemas.Store
  alias BitPalSchemas.Currency
  alias BitPalSchemas.CurrencySettings
  alias BitPalSchemas.AddressKey
  alias BitPal.Repo

  # Default vaLues can be overridden in config
  @default_required_confirmations Application.compile_env!(:bitpal, :required_confirmations)
  @default_double_spend_timeout Application.compile_env!(:bitpal, :double_spend_timeout)

  # Currency settings

  @spec fetch_address_key(Store.id(), Currency.id()) ::
          {:ok, AddressKey.t()} | {:error, :not_found}
  def fetch_address_key(store_id, currency_id) do
    if key = get_address_key(store_id, currency_id) do
      {:ok, key}
    else
      {:error, :not_found}
    end
  end

  @spec fetch_address_key!(Store.id(), Currency.id()) :: AddressKey.t()
  def fetch_address_key!(store_id, currency_id) do
    {:ok, key} = fetch_address_key(store_id, currency_id)
    key
  end

  @spec set_address_key(Store.id(), Currency.id(), String.t()) ::
          {:ok, AddressKey.t()} | {:error, Changeset.t()}
  def set_address_key(store_id, currency_id, key) when is_binary(key) do
    settings =
      get_or_create_currency_settings(store_id, currency_id)
      |> Repo.preload(:address_key)

    if settings.address_key do
      # Key exists, but hasn't been used yet so we can just update it.
      if is_used(settings.address_key) do
        # Key exists and has address references we'd like to keep, so disconnect it from settings.
        change(settings.address_key, currency_settings_id: nil)
        |> Repo.update!()

        insert_address_key(settings.id, currency_id, key)
      else
        change(settings.address_key, data: key)
        |> Repo.update()
      end
    else
      insert_address_key(settings.id, currency_id, key)
    end
  end

  defp is_used(address_key) do
    from(a in Address, where: a.address_key_id == ^address_key.id)
    |> Repo.exists?()
  end

  defp insert_address_key(settings_id, currency_id, key) do
    %AddressKey{currency_settings_id: settings_id, currency_id: currency_id}
    |> change(%{data: key})
    |> foreign_key_constraint(:currency_settings_id)
    |> foreign_key_constraint(:currency_id)
    |> Repo.insert()
  end

  @spec get_required_confirmations(Store.id(), Currency.id()) :: non_neg_integer
  def get_required_confirmations(store_id, currency_id) do
    get_simple(store_id, currency_id, :required_confirmations) || @default_required_confirmations
  end

  @spec set_required_confirmations(Store.id(), Currency.id(), non_neg_integer) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def set_required_confirmations(store_id, currency_id, confs) do
    set_simple(store_id, currency_id, :required_confirmations, confs)
  end

  @spec get_double_spend_timeout(Store.id(), Currency.id()) :: non_neg_integer
  def get_double_spend_timeout(store_id, currency_id) do
    get_simple(store_id, currency_id, :double_spend_timeout) || @default_double_spend_timeout
  end

  @spec set_double_spend_timeout(Store.id(), Currency.id(), non_neg_integer) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def set_double_spend_timeout(store_id, currency_id, timeout) do
    set_simple(store_id, currency_id, :double_spend_timeout, timeout)
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

  defp get_address_key(store_id, currency_id) do
    from(x in AddressKey,
      join: s in ^currency_settings_query(store_id, currency_id),
      where: x.currency_settings_id == s.id,
      select: x
    )
    |> Repo.one()
  end

  @spec get_simple(Store.id(), Currency.id(), atom) :: any()
  defp get_simple(store_id, currency_id, key) do
    from(x in currency_settings_query(store_id, currency_id),
      select: field(x, ^key)
    )
    |> Repo.one()
  end

  defp set_simple(store_id, currency_id, key, value) do
    case get_currency_settings(store_id, currency_id) do
      nil -> %CurrencySettings{store_id: store_id, currency_id: currency_id}
      settings -> settings
    end
    |> change(%{key => value})
    |> foreign_key_constraint(:currency_id)
    |> foreign_key_constraint(:store_id)
    |> Repo.insert_or_update()
  end

  defp get_or_create_currency_settings(store_id, currency_id) do
    case get_currency_settings(store_id, currency_id) do
      nil ->
        %CurrencySettings{store_id: store_id, currency_id: currency_id}
        |> change()
        |> foreign_key_constraint(:currency_id)
        |> foreign_key_constraint(:store_id)
        |> Repo.insert!()

      settings ->
        settings
    end
  end
end
