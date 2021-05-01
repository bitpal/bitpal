defmodule BitPal.InvoiceEvent do
  @moduledoc """
  Invoice update events.

  Events:

    * `{:state, state}` Where `state` can be:
        
        - `:wait_for_tx` when the transaction hasn't been seen yet.
        - `:wait_for_verification` when the transaction has been seen, but is waiting to be verified.
          This typically mean we're waiting to see if a fast double spend will appear.
        - `:wait_for_confirmations` when the transaction is the mempool but we're waiting for a confirmation.
      
    * `{:state, endstate, invoice}` Where `endstate` can be:

        - `:accepted` when the invoice has been accepted.
        - `{:denied, reason}` if the invoice wasn't accepted.
          Typically rejected by a dobule spend.
        - `{:canceled, reason}` if the invoice was canceled.

        Note that the invoice will be sent with the events as the handler will stop afterwards.

    * `{:confirmations, confirmation_count}` when a transaction has received a confirmation.
  """

  alias BitPal.Invoice
  alias Phoenix.PubSub
  require Logger

  @pubsub BitPal.PubSub

  @typep confirmation_count :: non_neg_integer
  @type msg ::
          {:state, state}
          | {:state, endstate, Invoice.t()}
          | {:confirmations, confirmation_count}
  @type state ::
          :wait_for_tx
          | :wait_for_verification
          | :wait_for_confirmations
  @type endstate ::
          :accepted
          | {:denied, :doublespend}
          | {:canceled, term}

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
    "invoice:" <> Invoice.id(invoice)
  end
end
