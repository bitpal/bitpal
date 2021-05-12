defmodule BitPal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    BitPal.Currencies.configure_money()

    children = [
      BitPal.Repo,
      {Phoenix.PubSub, name: BitPal.PubSub},
      BitPal.ProcessRegistry,
      BitPal.TransactionsOld,
      BitPal.BackendManager,
      BitPal.InvoiceManager,
      BitPal.ExchangeRateSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BitPal.Supervisor)
  end

  @impl true
  def config_change(changed, new, _removed) do
    BitPal.configure(changed)
    BitPal.configure(new)

    # Where to fetch defaults for removed values?
    # Propagate changed/new/removed instead?

    :ok
  end
end
