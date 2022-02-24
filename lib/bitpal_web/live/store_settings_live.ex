defmodule BitPalWeb.StoreSettingsLive do
  use BitPalWeb, :live_view
  import Ecto.Changeset
  alias BitPal.Authentication.Tokens
  alias BitPal.BackendManager
  alias BitPal.Currencies
  alias BitPal.Repo
  alias BitPal.Stores
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.CurrencySettings
  alias BitPalSettings.StoreSettings
  alias BitPalWeb.StoreLiveAuth
  require Logger

  on_mount StoreLiveAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    template = Atom.to_string(assigns.live_action) <> ".html"
    render(BitPalWeb.StoreSettingsView, template, assigns)
  end

  @impl true
  def handle_params(%{"crypto" => crypto, "store" => store_slug}, uri, socket) do
    case Currencies.cast(crypto) do
      {:ok, currency_id} ->
        socket =
          socket
          |> assign(currency_id: currency_id)
          |> init_assigns(uri)

        {:noreply, socket}

      :error ->
        {:noreply, redirect_to_general(socket, store_slug)}
    end
  end

  @impl true
  def handle_params(%{"store" => store_slug}, uri, socket) do
    if socket.assigns[:live_action] == :redirect do
      {:noreply,
       push_patch(
         socket,
         to: Routes.store_settings_path(socket, :general, store_slug),
         replace: true
       )}
    else
      {:noreply, init_assigns(socket, uri)}
    end
  end

  defp init_assigns(socket, uri) do
    socket
    |> assign(uri: uri)
    |> assign_breadcrumbs()
    |> assign_currency_ids()
    |> assign_live_action(socket.assigns.live_action)
  end

  defp assign_breadcrumbs(socket) do
    socket
    |> assign(breadcrumbs: Breadcrumbs.store_settings(socket, socket.assigns.uri))
  end

  defp assign_currency_ids(socket) do
    if socket.assigns[:currency_ids] do
      socket
    else
      store =
        socket.assigns.store
        |> Repo.preload([:currency_settings])

      currency_ids =
        (Enum.map(store.currency_settings, fn settings -> settings.currency_id end) ++
           BackendManager.currency_list())
        |> Enum.sort()
        |> Enum.dedup()

      assign(socket, store: store, currency_ids: currency_ids)
    end
  end

  defp assign_live_action(socket, :general) do
    assign(
      socket,
      edit_store: Stores.update_changeset(socket.assigns.store)
    )
  end

  defp assign_live_action(socket, :access_tokens) do
    store =
      socket.assigns.store
      |> Repo.preload([:access_tokens])

    assign(
      socket,
      store: store,
      create_token: tokens_changeset()
    )
  end

  defp assign_live_action(socket, :crypto) do
    currency_id = socket.assigns.currency_id
    store = socket.assigns.store

    settings =
      StoreSettings.get_or_create_currency_settings(store.id, currency_id)
      |> Repo.preload(:address_key)

    assign(
      socket,
      currency_changeset: change(settings),
      address_key_changeset: address_key_changeset(settings)
    )
  end

  defp assign_live_action(socket, _) do
    socket
  end

  defp address_key_changeset(settings = %CurrencySettings{}) do
    data = if settings.address_key, do: settings.address_key.data, else: nil
    address_key_changeset(data)
  end

  defp address_key_changeset(data) do
    %AddressKey{}
    |> change(data: data)
  end

  @impl true
  def handle_event("edit_store", %{"store" => params}, socket) do
    changeset = Stores.update_changeset(socket.assigns.store, params)

    case Stores.update(changeset) do
      {:ok, store} ->
        socket =
          assign(socket,
            store: store,
            edit_store: changeset
          )
          |> assign_breadcrumbs()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_store: changeset)}
    end
  end

  @impl true
  def handle_event("create_token", %{"access_token" => updates}, socket) do
    case Tokens.create_token(socket.assigns.store, Map.take(updates, ["label", "valid_until"])) do
      {:ok, token} ->
        {:noreply,
         assign(socket,
           created_token: token,
           store: Repo.preload(socket.assigns.store, :access_tokens, force: true)
         )}

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
      err ->
        Logger.warn("Failed to revoke token id: #{id} err: #{err}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("address_key", %{"address_key" => %{"data" => data}}, socket) do
    case StoreSettings.set_address_key(socket.assigns.store.id, socket.assigns.currency_id, data) do
      {:ok, address_key} ->
        {:noreply,
         assign(socket, address_key_changeset: %{change(address_key) | action: :success})}

      {:error, changeset} ->
        {:noreply, assign(socket, address_key_changeset: %{changeset | action: :fail})}
    end
  end

  @impl true
  def handle_event("currency_settings", %{"currency_settings" => updates}, socket) do
    case StoreSettings.update_simple(socket.assigns.store.id, socket.assigns.currency_id, updates) do
      {:ok, currency_settings} ->
        {:noreply,
         assign(socket, currency_changeset: %{change(currency_settings) | action: :success})}

      {:error, changeset} ->
        {:noreply, assign(socket, currency_changeset: %{changeset | action: :fail})}
    end
  end

  defp tokens_changeset(params \\ %{}) do
    %AccessToken{}
    |> change()
    |> cast(params, [:label])
  end

  defp redirect_to_general(socket, store_slug) do
    push_patch(
      socket,
      to: Routes.store_settings_path(socket, :general, store_slug),
      replace: true
    )
  end
end
