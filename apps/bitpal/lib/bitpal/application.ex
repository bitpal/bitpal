defmodule BitPal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        # BitPal.Repo,
        {Phoenix.PubSub, name: BitPal.PubSub},
        BitPal.ProcessRegistry
      ] ++ children_per_env(Mix.env())

    Supervisor.start_link(children, strategy: :one_for_one, name: BitPal.Supervisor)
  end

  def children_per_env(:test), do: []

  def children_per_env(_) do
    [
      {BitPal.BackendManager, Application.fetch_env!(:bitpal, :backends)},
      BitPal.InvoiceManager,
      BitPal.Transactions,
      BitPal.ExchangeRate
    ]
  end
end
