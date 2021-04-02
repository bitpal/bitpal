defmodule BitPal.InvoiceEvent do
  @moduledoc """
  Invoice update events.

  Events:

    * `{:state_changed, state}` Where `state` can be:
        
        - `:wait_for_tx` when the transaction hasn't been seen yet.
        - `:wait_for_verification` when the transaction has been seen, but is waiting to be verified.
          This typically mean we're waiting to see if a fast double spend will appear.
        - `:wait_for_confirmations` when the transaction is the mempool but we're waiting for a confirmation.
        - `:accepted` when the invoice has been accepted.
        - `{:denied, reason}` if the invoice wasn't accepted.
          Typically rejected by a dobule spend.
        - `{:canceled, reason}` if the invoice was canceled.
      
    * `{:confirmation, confirmation_count}` when a transaction has received a confirmation.
  """

  require Logger
  alias Phoenix.PubSub
  alias BitPal.Invoice

  @pubsub BitPal.PubSub

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
    "invoice:" <> Invoice.id(invoice)
  end
end
