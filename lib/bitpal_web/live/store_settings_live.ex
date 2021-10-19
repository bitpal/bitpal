defmodule BitPalWeb.StoreSettingsLive do
  use BitPalWeb, :live_view
  alias BitPal.Repo
  alias BitPal.Currencies
  alias BitPalSettings.StoreSettings
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)
  on_mount(BitPalWeb.StoreLiveAuth)

  @impl true
  def mount(%{"id" => _id}, _session, socket) do
    store = socket.assigns.store |> Repo.preload([:access_tokens])
    currencies = Currencies.all()

    currency_settings =
      currencies
      |> Enum.map(fn c ->
        settings =
          StoreSettings.get_currency_settings(store.id, c.id) ||
            StoreSettings.default_currency_settings()

        {c.id, settings}
      end)
      |> Enum.into(%{})
      |> IO.inspect()

    {:ok, assign(socket, store: store, currency_settings: currency_settings)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreSettingsView, "edit.html", assigns)
  end
end
