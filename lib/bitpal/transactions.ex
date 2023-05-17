defmodule BitPal.Transactions do
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias BitPal.AddressEvents
  alias BitPal.Blocks
  alias BitPal.Repo
  alias BitPal.Stores
  alias BitPal.Addresses
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  alias BitPalSchemas.Transaction
  alias BitPalSchemas.TxOutput
  require Logger

  @type height :: non_neg_integer
  @type confirmations :: non_neg_integer
  @type outputs :: [{Address.id(), Money.t()}]

  # External

  @spec fetch(Transaction.txid()) :: {:ok, Transaction.t()} | {:error, :not_found}
  def fetch(txid) do
    if tx = Repo.get_by(Transaction, id: txid) do
      {:ok, tx}
    else
      {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @spec fetch(Transaction.txid(), Store.id()) :: {:ok, Transaction.t()} | {:error, :not_found}
  def fetch(txid, store_id) do
    tx =
      from(t in Transaction,
        where: t.id == ^txid,
        left_join: out in TxOutput,
        on: out.transaction_id == t.id,
        left_join: i in Invoice,
        on: i.address_id == out.address_id,
        where: i.store_id == ^store_id,
        limit: 1
      )
      |> Repo.one()

    if tx do
      {:ok, tx}
    else
      {:error, :not_found}
    end
  rescue
    _ ->
      {:error, :not_found}
  end

  @spec all :: [Transaction.t()]
  def all do
    Repo.all(Transaction)
  end

  @spec to_address(Address.id()) :: [Transaction.t()]
  def to_address(address_id) do
    from(t in Transaction,
      left_join: out in TxOutput,
      on: out.transaction_id == t.id,
      where: out.address_id == ^address_id
    )
    |> Repo.all()
  end

  @spec pending(Currency.id()) :: [Transaction.t()]
  def pending(currency_id) do
    from(t in Transaction,
      where: t.currency_id == ^currency_id and t.height == 0
    )
    |> Repo.all()
  end

  @spec above_or_equal_height(Currency.id(), non_neg_integer) :: [Transaction.t()]
  def above_or_equal_height(currency_id, height) do
    from(t in Transaction,
      where: t.currency_id == ^currency_id and t.height >= ^height
    )
    |> Repo.all()
  end

  @spec address_tx_info(Address.id()) :: InvoiceEvents.txs()
  def address_tx_info(address_id) do
    # When we can aggregate money with sql using ex_money, we can rewrite this
    from(t in Transaction,
      left_join: out in TxOutput,
      on: out.transaction_id == t.id,
      where: out.address_id == ^address_id,
      group_by: t.id
    )
    |> Repo.all()
    |> Repo.preload(:outputs)
    |> Enum.map(fn tx ->
      %{
        txid: tx.id,
        height: tx.height,
        failed: tx.failed,
        double_spent: tx.double_spent,
        address_id: address_id,
        amount:
          Enum.reduce(tx.outputs, Money.new(0, tx.currency_id), fn out, acc ->
            if out.address_id == address_id do
              Money.add(out.amount, acc)
            else
              acc
            end
          end)
      }
    end)
  end

  @spec store_tx_info(Store.id()) :: InvoiceEvents.txs()
  def store_tx_info(store) do
    Stores.all_addresses(store)
    |> Enum.map(fn a -> address_tx_info(a.id) end)
    |> List.flatten()
  end

  # Data

  @spec num_confirmations!(Transaction.t()) :: confirmations
  def num_confirmations!(tx = %Transaction{currency: currency}) do
    num_confirmations(tx, Blocks.fetch_height!(currency))
  end

  @spec num_confirmations(Transaction.t(), height) :: confirmations
  def num_confirmations(%Transaction{height: tx_height}, block_height) do
    calc_confirmations(tx_height, block_height)
  end

  @spec calc_confirmations(height, height) :: confirmations
  def calc_confirmations(tx_height, block_height)
      when is_integer(tx_height) and tx_height > 0 and is_integer(block_height) and
             block_height > 0 do
    max(0, block_height - tx_height + 1)
  end

  def calc_confirmations(_, _) do
    0
  end

  # Internal updates

  @spec update(Transaction.id(), map | keyword) :: {:ok, Transaction.t()} | {:error, term}
  def update(txid, params) do
    params = Map.new(params)

    case fetch(txid) do
      {:ok, tx} ->
        update_tx(tx, params)

      _ ->
        insert_tx(txid, params)
    end
  end

  defp update_tx(existing, params) do
    case update_changeset(existing, params)
         |> Repo.update() do
      {:ok, updated} ->
        cond do
          updated == existing ->
            nil

          updated.double_spent && !existing.double_spent ->
            broadcast(updated, {:tx, :double_spent})

          updated.failed && !existing.failed ->
            broadcast(updated, {:tx, :failed})

          updated.height > 0 && existing.height == 0 ->
            broadcast(updated, {:tx, :confirmed}, height: updated.height)

          # There's an argument for sending :reversed instead of :failed when a confirmed
          # transaction is failed.
          # Prefer :failed because a :reversed is more temporary, while :failed is more definite
          # (although nothing is -really- permanent, so we should still recheck tx states).
          updated.height == 0 && existing.height > 0 ->
            broadcast(updated, {:tx, :reversed})

          updated.height != existing.height ->
            # Confirmed height changed. That's weird, but may happen after a reorg.
            # Just resend the confirmed message, I don't think we need a new :reorg message just for this?
            broadcast(updated, {:tx, :confirmed})

          true ->
            Logger.error("Unknown update")
        end

        {:ok, updated}

      err ->
        err
    end
  end

  defp insert_tx(txid, params) do
    with {:ok, outputs} <- filter_outputs(params),
         {:ok, tx} <-
           %Transaction{id: txid}
           |> insert_changeset(params, outputs)
           |> Repo.insert() do
      cond do
        tx.double_spent ->
          broadcast(tx, {:tx, :double_spent})

        tx.failed ->
          broadcast(tx, {:tx, :failed})

        tx.height > 0 ->
          broadcast(tx, {:tx, :confirmed}, height: tx.height)

        true ->
          broadcast(tx, {:tx, :pending})
      end

      {:ok, tx}
    else
      err -> err
    end
  end

  defp filter_outputs(%{outputs: outputs}) do
    known =
      Enum.map(outputs, fn {address, _} -> address end)
      |> Addresses.filter_exists()
      |> Enum.map(fn address -> address.id end)
      |> MapSet.new()

    res =
      outputs
      |> Enum.filter(fn {address, _} ->
        MapSet.member?(known, address)
      end)

    if Enum.empty?(res) do
      {:error, :no_known_output}
    else
      {:ok, res}
    end
  end

  defp filter_outputs(_) do
    {:error, :no_outputs}
  end

  defp insert_changeset(tx, params, outputs = [{_, %Money{currency: currency_id}} | _]) do
    change(tx, currency_id: currency_id)
    |> cast(params, [
      :height,
      :failed,
      :double_spent
    ])
    |> put_assoc(:outputs, Enum.map(outputs, &output_changeset/1))
    |> validate_number(:height, greater_than_or_equal_to: 0)
    |> unique_constraint(:id)
    |> foreign_key_constraint(:currency_id)
  end

  defp insert_changeset(tx, _params, _outputs) do
    change(tx)
    |> add_error(:outputs, "is invalid")
  end

  defp output_changeset({address, amount}) do
    change(%TxOutput{address_id: address})
    |> cast(%{amount: amount}, [:amount])
    |> foreign_key_constraint(:address_id)
  end

  defp update_changeset(tx, params) do
    # FIXME should be able to update outputs
    #
    # Is it fine to just ignore outputs? They should -never- change if things work as they should,
    # so I think it's fine to ignore them in all updates?
    change(tx)
    |> cast(params, [
      :height,
      :failed,
      :double_spent
    ])
    |> validate_number(:height, greater_than_or_equal_to: 0)
  end

  @spec broadcast(Transaction.t(), {atom, atom}, keyword) :: :ok
  defp broadcast(tx, tag, opts \\ []) do
    tx = Repo.preload(tx, :outputs)

    params = Enum.into(opts, %{id: tx.id})

    tx.outputs
    |> Enum.uniq_by(fn %{address_id: address_id} -> address_id end)
    |> Enum.each(fn %{address_id: address_id} ->
      AddressEvents.broadcast(
        address_id,
        {tag, Map.put(params, :address_id, address_id)}
      )
    end)
  end
end
