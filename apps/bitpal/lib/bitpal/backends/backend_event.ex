defmodule BitPal.BackendEvent do
  @moduledoc """
  Backend events.

  Events:

    * `{:tx_seen, amount}`
    * `:doublespend`
    * `{:additional_confirmation, confirmations}`
    * `{:block_reversed, doublespend?, confirmations}`
  """

  require Logger
  alias Phoenix.PubSub
  alias BitPal.Invoice

  @pubsub BitPal.PubSub

  # FIXME maybe these should be address based? Or currency based? Or something?
  @spec subscribe(Invoice.t()) :: :ok | {:error, term}
  def subscribe(invoice) do
    Logger.debug("subscribing to #{topic(invoice)}")
    PubSub.subscribe(@pubsub, topic(invoice))
  end

  @spec broadcast(Invoice.t(), term) :: :ok | {:error, term}
  def broadcast(invoice, msg) do
    Logger.debug("broadcasting #{inspect(msg)} to #{topic(invoice)}")
    PubSub.broadcast(@pubsub, topic(invoice), msg)
  end

  @spec topic(Invoice.t()) :: binary
  defp topic(invoice) do
    "addr:" <> invoice.address
  end
end
