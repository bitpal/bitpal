defmodule BitPal.Transactions do
  @moduledoc """
  This module is in charge of keeping track of all transactions that are in flight. Eventually,
  everything in here should be stored in a database in case we need to take down the server
  for maintenance or something like that.

  As such, it is vital that this process does not crash. Otherwise, we will lose transactions.
  """

  use GenServer
  require Logger
  alias BitPal.Invoice
  alias BitPal.BCH.Satoshi
  alias BitPal.BackendEvent

  # Minimum amount allowed in a single transaction.
  @min_satoshi 100

  # State of a single transaction that we keep track of.
  # State is one of:
  # - :pending - not seen yet
  # - :visible - visible in the blockchain
  # - an integer - indicates what block depth it was accepted into
  #
  # NOTE Should we rename them?
  # - :not_seen - not seen yet
  # - :in_mempool - seen, but not confirmed
  # - {:confirmed, height} - confirmed in the blockchain
  # - :double_spent - failed, it was double spent
  defmodule State do
    defstruct invoice: nil, state: :pending
  end

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Store a new transaction (via an Invoice).
  # Alters the amount of satoshis to ask for. This might
  # differ slightly from the original transaction as we need to keep it unique.
  @spec new(Invoice.t()) :: Invoice.t()
  def new(invoice) do
    GenServer.call(__MODULE__, {:new_transaction, invoice})
  end

  # Get the current height of the blockchain.
  def get_height() do
    GenServer.call(__MODULE__, {:get_height})
  end

  # Set the current height of the blockchain.
  def set_height(height) do
    GenServer.cast(__MODULE__, {:set_height, height})
  end

  # Notify us that a new transaction to "address" has been seen.
  def seen(address, amount) do
    GenServer.cast(__MODULE__, {:seen, address, amount})
  end

  # Notify us that a transaction was doublespent.
  def doublespend(address, amount) do
    GenServer.cast(__MODULE__, {:doublespend, address, amount})
  end

  # Notify us that a new transaction to "address" has been accepted into a block at "height"
  def accepted(address, amount, height) do
    GenServer.cast(__MODULE__, {:accepted, address, amount, height})
  end

  # Server API

  @impl true
  def init(state) do
    # Logger.info("Starting BitPal.Transactions")

    # Map of transactions. address -> satoshi value -> {data, watcher}
    state = Map.put(state, :transactions, %{})

    # Last seen block in the blockchain.
    state = Map.put(state, :height, 0)

    {:ok, state}
  end

  @impl true
  def handle_call({:new_transaction, invoice}, _from, state) do
    # IO.puts("registering new transaction! #{inspect(invoice.amount)}")
    transactions = Map.get(state, :transactions, %{})
    # Find a suitable addr map:
    for_addr = Map.get(transactions, invoice.address, %{})
    # Compute the amount to invoice.
    satoshi = find_amount(for_addr, Satoshi.from_decimal(invoice.amount).amount)
    # IO.puts("satoshis to invoice: #{inspect(satoshi)}")
    invoice = %{invoice | amount: Satoshi.to_decimal(%Satoshi{amount: satoshi})}

    # Put it back together.
    for_addr = Map.put(for_addr, satoshi, %State{invoice: invoice, state: :pending})

    transactions = Map.put(transactions, invoice.address, for_addr)
    state = Map.put(state, :transactions, transactions)

    {:reply, invoice, state}
  end

  @impl true
  def handle_call({:get_height}, _from, state) do
    {:reply, Map.get(state, :height, 0), state}
  end

  @impl true
  def handle_cast({:set_height, height}, state) do
    state = Map.put(state, :height, height)

    # Update all transactions.
    transactions = update_transactions(Map.get(state, :transactions, %{}), height)
    state = Map.put(state, :transactions, transactions)

    # IO.puts("After set height:")
    # IO.inspect(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:seen, address, amount}, state) do
    s = find(address, amount, state)

    state =
      if s == nil do
        state
      else
        new_s = %{s | state: :visible}
        send_seen(new_s)

        if done?(new_s, state_height(state)) do
          remove(address, amount, state)
        else
          replace(address, amount, new_s, state)
        end
      end

    # IO.puts("After 'seen'")
    # IO.inspect(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:doublespend, address, amount}, state) do
    s = find(address, amount, state)

    state =
      if s == nil do
        state
      else
        send_doublespend(s)
        remove(address, amount, state)
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:accepted, address, amount, height}, state) do
    s = find(address, amount, state)

    state =
      if s == nil do
        state
      else
        new_s = %{s | state: height}
        send_update(new_s, height)

        if done?(new_s, height) do
          remove(address, amount, state)
        else
          replace(address, amount, new_s, state)
        end
      end

    # IO.puts("After 'accepted'")
    # IO.inspect(state)

    {:noreply, state}
  end

  # Get the height, or nil.
  defp state_height(state) do
    Map.get(state, :height, nil)
  end

  # Update all transactions: we have a new block height!
  # Returns a new set of transactions.
  defp update_transactions(transactions, height) do
    update_transactions(Map.keys(transactions), transactions, height)
  end

  defp update_transactions(keys, transactions, height) do
    case keys do
      [first | rest] ->
        Map.put(
          update_transactions(rest, transactions, height),
          first,
          update_address(Map.get(transactions, first), height)
        )

      [] ->
        %{}
    end
  end

  # Update all elements in a single address.
  defp update_address(for_addr, height) do
    update_address(Map.keys(for_addr), for_addr, height)
  end

  defp update_address(keys, for_addr, height) do
    case keys do
      [first | rest] ->
        updated = update_single(Map.get(for_addr, first), height)

        if updated == nil do
          # It should be removed.
          update_address(rest, for_addr, height)
        else
          Map.put(update_address(rest, for_addr, height), first, updated)
        end

      [] ->
        %{}
    end
  end

  # Update a single transaction
  defp update_single(item, height) do
    send_update(item, height)

    if done?(item, height) do
      nil
    else
      item
    end
  end

  # Find a transaction given its address and amount. Returns nil if it is not found.
  defp find(address, amount, state) do
    transactions = Map.get(state, :transactions, %{})
    for_addr = Map.get(transactions, address, %{})
    amount = Satoshi.from_decimal(amount).amount
    Map.get(for_addr, amount, nil)
  end

  # Replace a transaction givent its address and amount. Returns new state.
  defp replace(address, amount, data, state) do
    transactions = Map.get(state, :transactions, %{})
    for_addr = Map.get(transactions, address, %{})
    for_addr = Map.put(for_addr, amount, data)
    transactions = Map.put(transactions, address, for_addr)
    Map.put(state, :transactions, transactions)
  end

  # Remove a transaction. Returns new state.
  defp remove(address, amount, state) do
    transactions = Map.get(state, :transactions, %{})
    for_addr = Map.get(transactions, address, %{})
    {_, new_for_addr} = Map.pop(for_addr, amount)
    transactions = Map.put(transactions, address, new_for_addr)
    Map.put(state, :transactions, transactions)
  end

  # Send a message indicating that a transaction was seen.
  defp send_seen(item) do
    BackendEvent.broadcast(item.invoice, :tx_seen)
  end

  # Send a message indicating we found a doublespend.
  defp send_doublespend(item) do
    BackendEvent.broadcast(item.invoice, :doublespend)
  end

  # Complete a transaction by sending any required messages.
  defp send_update(item, height) do
    if is_integer(item.state) do
      BackendEvent.broadcast(item.invoice, {:confirmations, height - item.state + 1})
    end
  end

  # Check if a State is completed and can be removed.
  defp done?(item, curr_height) do
    if curr_height == nil do
      false
    else
      case item.state do
        :pending ->
          false

        :visible ->
          # If visible, we're done if the transaction is zero-conf
          item.invoice.required_confirmations <= 0

        nr when is_integer(nr) ->
          # It's a number indicating the height it was seen at.
          # E.g. if curr_height == nr, that's one confirmation.
          curr_height - nr + 1 >= item.invoice.required_confirmations

        _ ->
          # Something else. Remove it.
          true
      end
    end
  end

  # Find a "free" satoshi amount for in the map.
  defp find_amount(available, satoshis) do
    case available do
      %{^satoshis => _} ->
        # Already used. Try decreasing the amount.
        find_amount(available, satoshis - 1)

      _ ->
        # Got it!
        if satoshis >= @min_satoshi do
          satoshis
        else
          # Indicate failure. All amounts over zero and lower than the invoiceed amount were zero.
          nil
        end
    end
  end
end
