defmodule BitPalWeb.StoreSettingsLive do
  use BitPalWeb, :live_view
  import Ecto.Changeset
  alias Ecto.Changeset
  alias BitPal.Repo
  alias BitPal.Stores
  alias BitPal.Currencies
  alias BitPalSettings.StoreSettings
  alias BitPal.BackendManager
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.CurrencySettings
  alias BitPal.Authentication.Tokens
  require Logger

  defmodule DisplayedSettings do
    defstruct [:settings, :settings_changeset, :address_key_changeset]

    def new(settings) do
      %DisplayedSettings{
        settings: settings,
        settings_changeset: change(settings),
        address_key_changeset: address_key_changeset(settings)
      }
    end

    defp address_key_changeset(settings) do
      data = if settings.address_key, do: settings.address_key.data, else: nil

      %AddressKey{}
      |> change(data: data)
    end

    def with_address_key_change(settings = %DisplayedSettings{}, address_key = %AddressKey{}) do
      currency_settings = %{settings.settings | address_key: address_key}

      %DisplayedSettings{
        settings: currency_settings,
        settings_changeset: change(currency_settings),
        address_key_changeset: %{address_key_changeset(currency_settings) | action: :success}
      }
    end

    def with_address_key_change(
          settings = %DisplayedSettings{},
          address_key_changeset = %Changeset{}
        ) do
      %{settings | address_key_changeset: %{address_key_changeset | action: :fail}}
    end

    def with_settings_change(
          settings = %DisplayedSettings{},
          currency_settings = %CurrencySettings{}
        ) do
      %{
        settings
        | settings: currency_settings,
          settings_changeset: %{change(currency_settings) | action: :success}
      }
    end

    def with_settings_change(settings = %DisplayedSettings{}, changeset = %Changeset{}) do
      %{settings | settings_changeset: %{changeset | action: :fail}}
    end
  end

  on_mount(BitPalWeb.UserLiveAuth)
  on_mount(BitPalWeb.StoreLiveAuth)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, init_assigns(socket)}
  end

  defp init_assigns(socket) do
    if socket.assigns[:currency_settings] do
      socket
    else
      store =
        socket.assigns.store
        |> Repo.preload([:access_tokens, currency_settings: :address_key])

      assign(socket,
        store: store,
        currency_settings: initial_currency_settings(store),
        # FIXME remove when styling is better
        created_token: %{
          label: "My awesome token",
          data: "SFMyNTY.g2gDYQFuBgAZBNaYfQFiAAFRgA.TZIBKkOxMKsU16yT_Xqo5RxxtonNM5hX5YZcl9FtU6Q"
        },
        create_token: tokens_changeset()
      )
    end
  end

  defp initial_currency_settings(store) do
    # Some settings may not have been created, so we need to fill up the settings list
    # with defaults.
    existing_settings =
      store.currency_settings
      |> Stream.map(fn settings ->
        {settings.currency_id, settings}
      end)
      |> Enum.into(%{})

    uninitialized_settings =
      BackendManager.currency_list()
      |> Stream.filter(&(!Map.has_key?(existing_settings, &1)))
      |> Stream.map(fn currency_id ->
        {currency_id, StoreSettings.create_default_settings(store.id, currency_id)}
      end)

    Stream.concat(existing_settings, uninitialized_settings)
    |> Stream.map(fn {currency_id, settings} ->
      {currency_id, DisplayedSettings.new(settings)}
    end)
    |> Enum.into(%{})
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "settings.html", assigns)
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
  end

  @impl true
  def handle_event("address_key", params, socket) do
    case extract_currency_updates(params) do
      {currency_id, updates} ->
        settings = socket.assigns.currency_settings[currency_id]
        data = Map.fetch!(updates, "data")

        case StoreSettings.set_address_key(settings.settings, data) do
          {:ok, address_key} ->
            {:noreply,
             assign_currency_setting(
               socket,
               currency_id,
               DisplayedSettings.with_address_key_change(settings, address_key)
             )}

          {:error, changeset} ->
            {:noreply,
             assign_currency_setting(
               socket,
               currency_id,
               DisplayedSettings.with_address_key_change(settings, changeset)
             )}
        end

      nil ->
        Logger.warn("Unknown currency in address_key update: #{inspect(Map.keys(params))}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("settings", params, socket) do
    case extract_currency_updates(params) do
      {currency_id, updates} ->
        settings = socket.assigns.currency_settings[currency_id]

        case StoreSettings.update_simple(socket.assigns.store.id, currency_id, updates) do
          {:ok, currency_settings} ->
            {:noreply,
             assign_currency_setting(
               socket,
               currency_id,
               DisplayedSettings.with_settings_change(settings, currency_settings)
             )}

          {:error, changeset} ->
            {:noreply,
             assign_currency_setting(
               socket,
               currency_id,
               DisplayedSettings.with_settings_change(settings, changeset)
             )}
        end

      nil ->
        Logger.warn("Unknown currency in settings update: #{inspect(Map.keys(params))}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_token", %{"access_token" => updates}, socket) do
    case Tokens.create_token(socket.assigns.store, Map.take(updates, ["label"])) do
      {:ok, token} ->
        {:noreply, assign(socket, created_token: token)}

      {:error, changeset} ->
        {:noreply, assign(socket, create_token: changeset)}
    end
  end

  @impl true
  def handle_event("revoke_token", %{"id" => id}, socket) do
    with {id, ""} <- Integer.parse(id),
         {:ok, token} <- Stores.find_token(socket.assigns.store, id) do
      Tokens.delete_token!(token)

      {:noreply,
       assign(socket, store: Repo.preload(socket.assigns.store, :access_tokens, force: true))}
    else
      _ ->
        # FIXME should have an "internal error" flash message or something?
        {:noreply, socket}
    end
  end

  defp tokens_changeset(params \\ %{}) do
    %AccessToken{}
    |> change()
    |> cast(params, [:label])
  end

  defp extract_currency_updates(params) do
    Enum.find_value(params, fn {key, val} ->
      case Currencies.cast(key) do
        {:ok, currency_id} ->
          {currency_id, val}

        :error ->
          nil
      end
    end)
  end

  defp assign_currency_setting(socket, currency_id, displayed_settings) do
    assign(
      socket,
      currency_settings:
        Map.put(
          socket.assigns.currency_settings,
          currency_id,
          displayed_settings
        )
    )
  end
end
