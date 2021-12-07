defmodule BitPalWeb.StoreSettingsLive do
  use BitPalWeb, :live_view
  import Ecto.Changeset
  alias BitPal.Repo
  alias BitPal.Currencies
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.AccessToken
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)
  on_mount(BitPalWeb.StoreLiveAuth)

  @impl true
  def mount(_params, _session, socket) do
    store =
      socket.assigns.store
      |> Repo.preload([:access_tokens, currency_settings: :address_key])

    # IO.inspect(_params)
    # IO.inspect(_session)
    # IO.inspect(socket.assigns)

    # currencies = Currencies.all()
    #
    # currency_settings =
    #   currencies
    #   |> Enum.map(fn c ->
    #     settings =
    #       StoreSettings.get_currency_settings(store.id, c.id) ||
    #         StoreSettings.default_currency_settings()
    #
    #     {c.id, settings}
    #   end)
    #   |> Enum.into(%{})

    create_token =
      %AccessToken{}
      |> Ecto.Changeset.change()

    currency_settings =
      store.currency_settings
      |> Enum.map(fn settings ->
        {settings.currency_id |> Atom.to_string(),
         settings_changeset(%{
           required_confirmations: settings.required_confirmations,
           address_key: settings.address_key.data
         })}
      end)

    {:ok,
     assign(socket,
       store: store,
       currency_settings: currency_settings,
       create_token: create_token
     )}
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
  def handle_event(event, params, socket) do
    IO.inspect(event)
    IO.inspect(params)

    {:noreply, socket}
  end

  defp settings_changeset(params \\ %{}) do
    form = %{required_confirmations: :integer, address_key: :string}

    {%{}, form}
    |> cast(params, Map.keys(form))
    |> validate_number(:required_confirmations,
      greater_than_or_equal_to: 0,
      message: "Must be a number from 0 or up"
    )
  end
end
