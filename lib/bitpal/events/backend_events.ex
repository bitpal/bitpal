defmodule BitPal.BackendEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Currency

  @type status_event ::
          {:started, :ready}
          | {:started, {:syncing, float}}
          | :stopped
  @type msg :: {{:backend, status_event}, Currency.id()}

  @spec subscribe(Currency.id()) :: :ok | {:error, term}
  def subscribe(id), do: EventHelpers.subscribe(topic(id))

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg = {_, id}) do
    EventHelpers.broadcast(topic(id), msg)
  end

  @spec topic(Currency.id()) :: binary
  defp topic(id) do
    "backend:#{id}"
  end
end
