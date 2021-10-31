defmodule BitPal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias BitPal.Currencies

  @impl true
  def start(_type, _args) do
    BitPal.Currencies.configure_money()

    children = [
      # Always start
      BitPal.Repo,
      Supervisor.child_spec({Phoenix.PubSub, name: BitPal.PubSub}, id: BitPal.PubSub),
      Supervisor.child_spec({Phoenix.PubSub, name: BitPalApi.PubSub}, id: BitPalApi.PubSub),
      Supervisor.child_spec({Phoenix.PubSub, name: BitPalWeb.PubSub}, id: BitPalWeb.PubSub),
      BitPal.ProcessRegistry,
      {Task.Supervisor, name: BitPal.TaskSupervisor},
      BitPalApi.Endpoint,
      BitPalWeb.Telemetry,
      BitPalWeb.Endpoint,
      {BitPal.Cache, name: BitPal.RuntimeStorage, ttl_check_interval: false},

      # Only start if configured to
      BitPal.ExchangeRateSupervisor,
      BitPal.InvoiceManager,
      BitPal.BackendManager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BitPal.Supervisor)
  end

  @impl true
  def config_change(changed, new, removed) do
    BitPalSettings.config_change(changed, new, removed)
    BitPalApi.Endpoint.config_change(changed, removed)
    BitPalWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def start_lean do
    Currencies.configure_money()

    # Avoid starting the application because it's really heavy. This is the lean way.
    for app <- Application.spec(:bitpal, :applications) do
      Application.ensure_all_started(app)
    end

    children = [
      BitPal.Repo,
      BitPalWeb.Endpoint,
      Supervisor.child_spec({Phoenix.PubSub, name: BitPalWeb.PubSub}, id: BitPalWeb.PubSub),
      Supervisor.child_spec(
        {BitPal.Cache, name: BitPal.RuntimeStorage, ttl_check_interval: false},
        id: BitPal.RuntimeStorage
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BitPal.Supervisor)
  end
end
