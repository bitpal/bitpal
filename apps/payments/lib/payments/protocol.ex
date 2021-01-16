defmodule Payments.Protocol do
  use Bitwise
  alias Payments.Connection.Binary
  alias Payments.Connection.RawMsg

  # Service names
  @service_api 0
  @service_blockchain 1
  @service_livetransactions 2
  @service_util 3
  @service_test 4
  @service_addressmonitor 17
  @service_blocknotification 18
  @service_indexer 19
  @service_system 126

  # dummy function to disable warnings...
  def dummy() do
    [
      @service_api,
      @service_blockchain,
      @service_livetransactions,
      @service_util,
      @service_test,
      @service_addressmonitor,
      @service_blocknotification,
      @service_indexer,
      @service_system
    ]
  end

  # Helper to extract a particular key from a message
  defp get_key(key, body) do
    case body do
      [{^key, v} | _rest] ->
        v

      [{_, _} | rest] ->
        get_key(key, rest)
    end
  end

  # Helper to get a number of keys at the same time. This is not very efficient...
  # 'keys' is a keyval list, returns a map.
  defp get_keys(keys, body) do
    case keys do
      [{name, first} | rest] ->
        Map.put(get_keys(rest, body), name, get_key(first, body))

      [] ->
        %{}
    end
  end

  # Like get_key, but returns nil if the key is not found.
  defp get_key_opt(key, body) do
    case body do
      [{^key, v} | _rest] ->
        v

      [{_, _} | rest] ->
        get_key_opt(key, rest)

      [] ->
        nil
    end
  end

  # Same as get_keys, but ignores missing keys.
  defp get_keys_opt(keys, body) do
    case keys do
      [{name, first} | rest] ->
        val = get_key_opt(first, body)
        k = get_keys_opt(rest, body)

        if val != nil do
          Map.put(k, name, val)
        else
          k
        end

      [] ->
        %{}
    end
  end

  # Helper to send
  defp send_msg(c, serviceId, messageId, data) do
    Payments.Connection.send(c, %RawMsg{service: serviceId, message: messageId, data: data})
  end

  # Send a ping to the remote peer. We need to do this about once every minute. Otherwise, we will
  # be disconnected after 120 s. It seems it does not matter if we send other data, we will still be
  # disconnected if we don't send ping messages.
  def send_ping(c) do
    Payments.Connection.send(c, %RawMsg{service: @service_system, ping: true})
  end

  # Send a version request message. Returns a string.
  def send_version(c) do
    send_msg(c, 0, 0, [])
  end

  # Ask for blockchain info.
  def send_blockchain_info(c) do
    send_msg(c, @service_blockchain, 0, [])
  end

  # Subscribe to get notified of blocks.
  def send_block_subscribe(c) do
    send_msg(c, @service_blocknotification, 0, [])
  end

  # Unsubscribe to get notified of blocks.
  def send_block_unsubscribe(c) do
    send_msg(c, @service_blocknotification, 2, [])
  end

  # Get options for the get operation.
  defp get_output(output) do
    case output do
      [] -> []
      [:transactionId | rest] -> [{43, true} | get_output(rest)]
      [:offset | rest] -> [{44, true} | get_output(rest)]
      [:inputs | rest] -> [{46, true} | get_output(rest)]
      [:outputs | rest] -> [{49, true} | get_output(rest)]
      [:outputAddrs | rest] -> [{50, true} | get_output(rest)]
      [:amounts | rest] -> [{47, true} | get_output(rest)]
    end
  end

  # Get a block in the blockchain.
  def send_get_block(c, {:height, h}, outputs) do
    send_msg(c, @service_blockchain, 4, [{7, h} | get_output(outputs)])
  end

  def send_get_block(c, {:hash, h}, outputs) do
    send_msg(c, @service_blockchain, 4, [{7, %Binary{data: h}} | get_output(outputs)])
  end

  # Convert addresses into a message. Handles either a single address or a list of them.
  defp convert_addresses(address) do
    case address do
      [addr | rest] ->
        [{9, %Binary{data: addr}} | convert_addresses(rest)]

      [] ->
        []

      a ->
        [{9, %Binary{data: a}}]
    end
  end

  # Monitor a particular address. "address" is a "script encoded" address. See the Address module.
  def send_address_subscribe(c, address) do
    conv = convert_addresses(address)
    send_msg(c, @service_addressmonitor, 0, conv)
  end

  # Stop subscribing to an address.
  def send_address_unsubscribe(c, address) do
    conv = convert_addresses(address)
    send_msg(c, @service_addressmonitor, 2, conv)
  end

  # List available indexers.
  def send_find_avail_indexers(c) do
    send_msg(c, @service_indexer, 0, [])
  end

  # Find a transaction. Note: Hashes seem to be reversed compared to what is shown on eg. Blockchain Explorer.
  def send_find_transaction(c, bytes) do
    send_msg(c, @service_indexer, 2, [{4, %Binary{data: bytes}}])
  end

  # Structure for received message.
  defmodule Message do
    defstruct type: nil, data: %{}
  end

  # Helper to create messages
  def make_msg(type, keys, body) do
    %Message{type: type, data: get_keys(keys, body)}
  end

  # Helper to create a message. Does not care if some key is missing.
  def make_msg_opt(type, keys, body) do
    %Message{type: type, data: get_keys_opt(keys, body)}
  end

  # Receive some message (blocking)
  def recv(c) do
    msg = Payments.Connection.recv(c)
    %RawMsg{service: service, message: message, data: body} = msg

    case {service, message} do
      {@service_api, 1} ->
        # Version message
        make_msg(:version, [version: 1], body)

      {@service_blockchain, 1} ->
        # Reply from "blockchain info"
        make_msg(
          :version,
          [
            difficulty: 64,
            medianTime: 65,
            chainWork: 66,
            chain: 67,
            blocks: 68,
            headers: 69,
            bestBlockHash: 70,
            verificationProgress: 71
          ],
          body
        )

      {@service_blockchain, 5} ->
        # Answer to "get block". This requires more intricate parsing...
        %Message{type: :block, data: parse_get_block(body)}

      {@service_blocknotification, 4} ->
        # Notified of a block
        make_msg(:newBlock, [blockHash: 5, blockHeight: 7], body)

      {@service_addressmonitor, 1} ->
        # Reply for subscriptions. Note: The documentation is incorrect with the IDs here.
        make_msg_opt(:subscribeReply, [result: 21, error: 20], body)

      {@service_addressmonitor, 3} ->
        # Sent when an address we monitor is involved in a transaction. Offset is only present when
        # the transaction is accepted in a block.
        make_msg_opt(
          :transaction,
          [transactionId: 4, address: 9, amount: 6, height: 7, offset: 8],
          body
        )

      {@service_addressmonitor, 4} ->
        # Sent when a double-spend is found.
        make_msg_opt(
          :doubleSpend,
          [transactionId: 4, address: 9, amount: 6, transaction: 1],
          body
        )

      {@service_indexer, 1} ->
        # Indexer reply to what it is indexing.
        make_msg_opt(:availableIndexers, [address: 21, transaction: 22, spentOutput: 23], body)

      {@service_indexer, 3} ->
        # Indexer reply to "find transaction"
        make_msg(:transaction, [height: 7, offsetInBlock: 8], body)

      {@service_system, nil} ->
        # Probably a ping response. We don't need to be very fancy.
        %Message{type: :pong}

      _ ->
        # Unknown message!
        raise(
          "Unknown message: " <>
            Kernel.inspect({service, message}) <> " " <> Kernel.inspect(msg.data)
        )
    end
  end

  # Parse the data inside a block info message.
  defp parse_get_block(body) do
    data = parse_get_block(body, %{transactions: []})
    Map.put(data, :transactions, Enum.reverse(data[:transactions]))
  end

  defp parse_get_block(body, data) do
    case body do
      [] ->
        # Done!
        data

      [{7, height} | rest] ->
        parse_get_block(rest, Map.put(data, :height, height))

      [{5, %Binary{data: hash}} | rest] ->
        parse_get_block(rest, Map.put(data, :hash, hash))

      [{1, %Binary{data: raw}} | rest] ->
        parse_get_block(rest, Map.put(data, :raw, raw))

      [{8, _} | _] ->
        # Note: Transactions will be in reverse order compared to what we get from flowee. We reverse the list later.
        {rest, new_transaction} = parse_get_transaction(body, %{})
        transactions = [new_transaction | data[:transactions]]
        parse_get_block(rest, Map.put(data, :transactions, transactions))
    end
  end

  # Parse a single transaction inside a get_block request. They are terminated by a SEPARATOR tag (id 0)
  # Returns { remaining, transaction }
  defp parse_get_transaction(body, data) do
    case body do
      [] ->
        # In case the last separator is missing.
        {[], fix_transaction(data)}

      [{0, _} | rest] ->
        # Separator, we're done.
        {rest, fix_transaction(data)}

      [{8, offset} | rest] ->
        parse_get_transaction(rest, Map.put(data, :offset, offset))

      [{4, %Binary{data: id}} | rest] ->
        parse_get_transaction(rest, Map.put(data, :transactionId, id))

      [{20, %Binary{data: txid}} | rest] ->
        {r, input} = parse_input(rest, %{transactionId: txid})
        inputs = [input | Map.get(data, :inputs, [])]
        parse_get_transaction(r, Map.put(data, :inputs, inputs))

      [{22, _} | _] ->
        # Sometimes there is a lone InputScript (for the first one, usually?)
        {r, input} = parse_input(body, %{})
        inputs = [input | Map.get(data, :inputs, [])]
        parse_get_transaction(r, Map.put(data, :inputs, inputs))

      [{24, id} | rest] ->
        {r, output} = parse_output(rest, %{id: id})
        outputs = [output | Map.get(data, :outputs, [])]
        parse_get_transaction(r, Map.put(data, :outputs, outputs))
    end
  end

  # Fixup the transaction when we're done with it (i.e. reverse the lists in it)
  defp fix_transaction(t) do
    t =
      case t do
        %{inputs: i} -> Map.put(t, :inputs, Enum.reverse(i))
        _ -> t
      end

    t =
      case t do
        %{outputs: o} -> Map.put(t, :outputs, Enum.reverse(o))
        _ -> t
      end

    t
  end

  defp parse_input(body, data) do
    case body do
      [] ->
        {[], data}

      [{21, id} | rest] ->
        parse_input(rest, Map.put(data, :transactionIndex, id))

      [{22, %Binary{data: script}} | rest] ->
        parse_input(rest, Map.put(data, :script, script))

      [{_, _} | _] ->
        {body, data}
    end
  end

  defp parse_output(body, data) do
    case body do
      [] ->
        {[], data}

      [{2, %Binary{data: address}} | rest] ->
        # Note: This is not in the documentation.........
        # It is a "ripe160 based P2PKH address"
        parse_output(rest, Map.put(data, :address, address))

      [{6, amount} | rest] ->
        parse_output(rest, Map.put(data, :amount, amount))

      [{23, %Binary{data: script}} | rest] ->
        parse_output(rest, Map.put(data, :script, script))

      [{_, _} | _] ->
        # Some other element we don't recognize. Go back to the caller.
        {body, data}
    end
  end
end
