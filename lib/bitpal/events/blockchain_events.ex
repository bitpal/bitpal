defmodule BitPal.BlockchainEvents do
  alias BitPal.EventHelpers
  alias BitPalSchemas.Currency

  @type height :: non_neg_integer()
  @type msg ::
          {{:block, :set_height}, Currency.id(), height}
          | {{:block, :new}, Currency.id(), height}
          | {{:block, :reversed}, Currency.id(), height}

  @spec subscribe(Currency.id()) :: :ok | {:error, term}
  def subscribe(id) do
    EventHelpers.subscribe(topic(id))
  end

  @spec broadcast(Currency.id(), msg) :: :ok | {:error, term}
  def broadcast(id, msg) do
    EventHelpers.broadcast(topic(id), msg)
  end

  defp topic(id) do
    "blockchain:" <> Atom.to_string(id)
  end
end
