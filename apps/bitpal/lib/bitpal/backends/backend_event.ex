defmodule BitPal.BackendEvent do
  @moduledoc """
  Backend events.

  Events:

    * `:tx_seen`
    * `:doublespend`
    * `{:confirmations, confirmation_count}`
    * `{:block_reversed, doublespend?, confirmation_count}`
  """

  require Logger
  alias Phoenix.PubSub
  alias BitPal.Invoice

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
    Logger.debug("subscribing to #{topic(invoice)} #{inspect(self())}")
    PubSub.subscribe(@pubsub, topic(invoice))
  end

  @spec broadcast(Invoice.t(), msg) :: :ok | {:error, term}
  def broadcast(invoice, msg) do
    Logger.debug("broadcasting #{inspect(msg)} to #{topic(invoice)}")
    PubSub.broadcast(@pubsub, topic(invoice), msg)
  end

  @spec topic(Invoice.t()) :: binary
  defp topic(invoice) do
    "backend:" <> Invoice.id(invoice)
  end
end
