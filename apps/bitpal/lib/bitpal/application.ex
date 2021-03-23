defmodule BitPal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # FIXME look at the configuration file and start the specified adapters
    children = [
      # Start the Ecto repository
      # BitPal.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: BitPal.PubSub},
      # Start a worker by calling: BitPal.Worker.start_link(arg)
      # {BitPal.Worker, arg}
      BitPal.Flowee,
      BitPal.Transactions,
      BitPal.ExchangeRate
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BitPal.Supervisor)
  end
end
