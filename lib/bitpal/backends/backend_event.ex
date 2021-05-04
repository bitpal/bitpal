defmodule BitPal.BackendEvent do
  @moduledoc """
  Backend events.

  Events:

    * `:tx_seen`
    * `:doublespend`
    * `{:confirmations, confirmation_count}`
    * `{:block_reversed, doublespend?, confirmation_count}`
  """

  alias BitPalSchemas.Invoice
  alias Phoenix.PubSub
  require Logger

  @pubsub BitPal.PubSub

  @typep confirmation_count :: non_neg_integer
  @typep doublespend? :: boolean
  @type msg ::
          :tx_seen
          | :doublespend
          | {:confirmations, confirmation_count}
          | {:block_reversed, doublespend?, confirmation_count}

  @spec subscribe(Invoice.t()) :: :ok | {:error, term}
  def subscribe(invoice) do
    topic = topic(invoice)
    Logger.debug("subscribing to #{topic} #{inspect(self())}")
    PubSub.subscribe(@pubsub, topic)
  end

  @spec broadcast(Invoice.t(), msg) :: :ok | {:error, term}
  def broadcast(invoice, msg) do
    topic = topic(invoice)
    Logger.debug("broadcasting #{inspect(msg)} to #{topic}")
    PubSub.broadcast(@pubsub, topic, msg)
  end

  @spec topic(Invoice.t()) :: binary
  defp topic(invoice) do
    "backend:" <> invoice.id
  end
end
