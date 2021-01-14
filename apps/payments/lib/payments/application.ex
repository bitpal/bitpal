defmodule Payments.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Payments.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Payments.PubSub},
      # Start a worker by calling: Payments.Worker.start_link(arg)
      # {Payments.Worker, arg}
      Payments.Node
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Payments.Supervisor)
  end
end
