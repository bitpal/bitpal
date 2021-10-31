defmodule BitPal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Always start
      BitPal.Repo,
      Supervisor.child_spec({Phoenix.PubSub, name: BitPal.PubSub}, id: BitPal.PubSub),
      Supervisor.child_spec({Phoenix.PubSub, name: BitPalApi.PubSub}, id: BitPalApi.PubSub),
      Supervisor.child_spec({Phoenix.PubSub, name: BitPalWeb.PubSub}, id: BitPalWeb.PubSub),
      BitPal.ProcessRegistry,
      Supervisor.child_spec({Task.Supervisor, name: BitPal.TaskSupervisor},
        id: BitPal.TaskSupervisor
      ),
      Supervisor.child_spec(
        {BitPal.Cache, name: BitPal.RuntimeStorage, ttl_check_interval: false},
        id: BitPal.RuntimeStorage
      ),
      BitPalApi.Endpoint,
      BitPalWeb.Telemetry,
      BitPalWeb.Endpoint,
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
end
