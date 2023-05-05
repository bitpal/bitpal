defmodule BitPalSettings.StoreSettings do
  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset
  alias BitPal.Currencies
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Currency
  alias BitPalSchemas.CurrencySettings
  alias BitPalSchemas.Store
  alias Ecto.Changeset

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

    set_address_key(settings, key)
  end

  @spec set_address_key(CurrencySettings.t(), String.t()) ::
          {:ok, AddressKey.t()} | {:error, Changeset.t()}
  def set_address_key(settings = %CurrencySettings{address_key: address_key = %AddressKey{}}, key)
      when is_binary(key) do
    cond do
      # We're already up to date.
      address_key.data == key ->
        {:ok, address_key}

      # Key exists and has address references we'd like to keep, so disconnect it from settings.
      is_used(address_key) ->
        change(address_key, currency_settings_id: nil)
        |> Repo.update!()

        insert_address_key(settings.id, settings.currency_id, key)

      # Key exists, but hasn't been used yet so we can just update it.
      true ->
        address_key
        |> address_key_change(key, settings.currency_id)
        |> Repo.update()
    end
  end

  def set_address_key(settings, key) when is_binary(key) do
    insert_address_key(settings.id, settings.currency_id, key)
  end

  defp is_used(address_key) do
    from(a in Address, where: a.address_key_id == ^address_key.id)
    |> Repo.exists?()
  end

  defp address_key_change(address_key, key, currency_id) do
    address_key
    |> change(%{data: key})
    |> validate_address_key_data(:data, currency_id: currency_id)
    |> foreign_key_constraint(:currency_settings_id)
    |> foreign_key_constraint(:currency_id)
    |> unique_constraint(:data, name: :address_keys_data_index)
  end

  defp insert_address_key(settings_id, currency_id, key) when is_binary(key) do
    %AddressKey{currency_settings_id: settings_id, currency_id: currency_id}
    |> address_key_change(key, currency_id)
    |> Repo.insert()
  end

  @spec address_key_store(AddressKey.t()) :: {:ok, Store.t()} | :error
  def address_key_store(address_key) do
    res =
      from(s in Store,
        left_join: cs in CurrencySettings,
        on: cs.store_id == s.id,
        where: ^address_key.currency_settings_id == cs.id,
        select: s
      )
      |> Repo.one()

    if res do
      {:ok, res}
    else
      :error
    end
  end

  @spec validate_address_key_data(Changeset.t(), atom, keyword) :: Changeset.t()
  def validate_address_key_data(changeset, data_key, opts) do
    currency_id = Keyword.fetch!(opts, :currency_id)
    data = get_change(changeset, data_key)

    cond do
      data == "" ->
        add_error(changeset, :data, "cannot be empty")

      Currencies.valid_address_key?(currency_id, data) ->
        changeset

      true ->
        add_error(changeset, :data, "invalid key")
    end
  end

  @spec get_required_confirmations(Store.id(), Currency.id()) :: non_neg_integer
  def get_required_confirmations(store_id, currency_id) do
    get_simple(store_id, currency_id, :required_confirmations) || @default_required_confirmations
  end

  @spec set_required_confirmations(Store.id(), Currency.id(), non_neg_integer) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def set_required_confirmations(store_id, currency_id, confs) do
    update_simple(store_id, currency_id, required_confirmations: confs)
  end

  @spec get_double_spend_timeout(Store.id(), Currency.id()) :: non_neg_integer
  def get_double_spend_timeout(store_id, currency_id) do
    get_simple(store_id, currency_id, :double_spend_timeout) || @default_double_spend_timeout
  end

  @spec set_double_spend_timeout(Store.id(), Currency.id(), non_neg_integer) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def set_double_spend_timeout(store_id, currency_id, timeout) do
    update_simple(store_id, currency_id, double_spend_timeout: timeout)
  end

  @spec get_or_create_currency_settings(Store.id(), Currency.id()) :: CurrencySettings.t() | nil
  def get_or_create_currency_settings(store_id, currency_id) do
    get_currency_settings(store_id, currency_id) ||
      create_default_currency_settings(store_id, currency_id)
  end

  @spec get_currency_settings(Store.id(), Currency.id()) :: CurrencySettings.t() | nil
  def get_currency_settings(store_id, currency_id) do
    currency_settings_query(store_id, currency_id)
    |> Repo.one()
  end

  @spec create_default_currency_settings(Store.id(), Currency.id()) :: CurrencySettings.t()
  def create_default_currency_settings(store_id, currency_id) do
    %CurrencySettings{
      store_id: store_id,
      currency_id: currency_id,
      double_spend_timeout: @default_double_spend_timeout,
      required_confirmations: @default_required_confirmations,
      address_key: nil
    }
    |> change()
    |> foreign_key_constraint(:currency_id)
    |> foreign_key_constraint(:store_id)
    |> Repo.insert!()
  end

  defp currency_settings_query(store_id, currency_id) do
    from(x in CurrencySettings,
      where: x.store_id == ^store_id and x.currency_id == ^Atom.to_string(currency_id)
    )
  end

  defp get_address_key(store_id, currency_id) do
    from(x in AddressKey,
      join: s in ^currency_settings_query(store_id, currency_id),
      on: x.currency_settings_id == s.id,
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

  @spec update_simple(Store.id(), Currency.id(), map | keyword) ::
          {:ok, CurrencySettings.t()} | {:error, Changeset.t()}
  def update_simple(store_id, currency_id, params) do
    case get_currency_settings(store_id, currency_id) do
      nil -> %CurrencySettings{store_id: store_id, currency_id: currency_id}
      settings -> settings
    end
    |> cast(Enum.into(params, %{}), [:required_confirmations, :double_spend_timeout])
    |> foreign_key_constraint(:currency_id)
    |> foreign_key_constraint(:store_id)
    |> validate_number(:required_confirmations, greater_than_or_equal_to: 0)
    |> validate_number(:double_spend_timeout, greater_than: 0)
    |> Repo.insert_or_update()
  end
end
