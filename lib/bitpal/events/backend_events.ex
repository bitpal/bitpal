defmodule BitPal.BackendEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.Backend
  alias BitPal.EventHelpers
  alias BitPalSchemas.Currency

  @type msg ::
          {{:backend, :status}, %{status: Backend.backend_status(), currency_id: Currency.id()}}
          | {{:backend, :set_enabled}, %{currency_id: Currency.id(), is_enabled: boolean}}
          | {{:backend, :info}, %{info: Backend.backend_info(), currency_id: Currency.id()}}

  @spec subscribe(Currency.id()) :: :ok | {:error, term}
  def subscribe(id), do: EventHelpers.subscribe(topic(id))

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg = {_, %{currency_id: id}}) do
    EventHelpers.broadcast(topic(id), msg)
  end

  @spec topic(Currency.id()) :: binary
  defp topic(id) do
    "backend:#{id}"
  end
end
