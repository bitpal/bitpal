defmodule BitPal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  # NOTE instead of starting it in a weird way in test cases,
  # send args here and control setup.
  def start(_type, _args) do
    BitPal.Currencies.configure_money()

    children = [
      # Always start
      BitPal.Repo,
      {Phoenix.PubSub, name: BitPal.PubSub},
      BitPal.ProcessRegistry,
      BitPalApi.Endpoint,
      BitPalWeb.Telemetry,
      BitPalWeb.Endpoint,
      {BitPal.Cache, name: BitPal.RuntimeStorage, clear_interval: :inf},

      # Only start if configured to
      BitPal.ExchangeRateSupervisor,
      BitPal.InvoiceManager,
      BitPal.BackendManager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BitPal.Supervisor)
  end

  @impl true
  def config_change(changed, new, removed) do
    BitPal.configure(changed)
    BitPal.configure(new)
    BitPalApi.Endpoint.config_change(changed, removed)
    BitPalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
