defmodule BitPal.Transactions do
  alias BitPal.AddressEvents
  alias BitPal.Blocks
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Transaction
  alias Ecto.Changeset
  require Logger

  @type height :: non_neg_integer
  @type confirmations :: non_neg_integer

  @spec num_confirmations!(Transaction.t()) :: confirmations
  def num_confirmations!(%Transaction{confirmed_height: height, currency: currency}) do
    num_confirmations!(height, currency.id)
  end

  @spec num_confirmations!(height, Currency.id()) :: confirmations
  def num_confirmations!(height, currency_id) when is_integer(height) and height >= 0 do
    max(0, Blocks.fetch_block_height!(currency_id) - height + 1)
  end

  def num_confirmations!(height, _) when is_integer(height) and height < 0 do
    0
  end

  def num_confirmations!(nil, _) do
    0
  end

  @spec seen(Transaction.id(), Address.id(), Money.t()) ::
          {:ok, Transaction.t()} | {:error, Changeset.t()}
  def seen(txid, address_id, amount) do
    res =
      Repo.insert(
        %Transaction{
          id: txid,
          address_id: address_id,
          amount: amount
        },
        on_conflict: :nothing
      )

    case res do
      {:ok, tx} ->
        AddressEvents.broadcast(address_id, {:tx_seen, Repo.preload(tx, :currency)})
        res

      {:error, changeset} ->
        Logger.warn("Failed to insert tx: #{inspect(changeset)}")
        res
    end
  end

  @spec confirmed(Transaction.id(), Address.id(), Money.t(), height) ::
          {:ok, Transaction.t()} | {:error, Changeset.t()}
  def confirmed(txid, address_id, amount, height) do
    res = update(txid, address_id, amount, confirmed_height: height)

    case res do
      {:ok, tx} ->
        AddressEvents.broadcast(address_id, {:tx_confirmed, tx})
        res

      _ ->
        res
    end
  end

  @spec double_spent(Transaction.id(), Address.id(), Money.t()) ::
          {:ok, Transaction.t()} | {:error, Changeset.t()}
  def double_spent(txid, address_id, amount) do
    res = update(txid, address_id, amount, double_spent: true)

    case res do
      {:ok, tx} ->
        AddressEvents.broadcast(address_id, {:tx_double_spent, tx})
        res

      _ ->
        res
    end
  end

  @spec reversed(Transaction.id(), Address.id(), Money.t(), height) ::
          {:ok, Transaction.t()} | {:error, Changeset.t()}
  def reversed(txid, address_id, amount, _height) do
    res = update(txid, address_id, amount, confirmed_height: nil)

    case res do
      {:ok, tx} ->
        AddressEvents.broadcast(address_id, {:tx_reversed, tx})
        res

      _ ->
        res
    end
  end

  defp update(txid, address_id, amount, changes) do
    res =
      case Repo.get(Transaction, txid) do
        nil -> %Transaction{id: txid, address_id: address_id, amount: amount}
        tx -> tx
      end
      |> Changeset.change(changes)
      |> Repo.insert_or_update()

    case res do
      {:error, changeset} ->
        Logger.warn("Failed to update tx: #{inspect(changeset)}")
        res

      {:ok, tx} ->
        {:ok, Repo.preload(tx, :currency)}
    end
  end
end
