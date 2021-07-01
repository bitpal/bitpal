defmodule BitPal.Backend.Flowee.Protocol do
  @moduledoc """
  High-level protocol for the Flowee backend.

  Uses the Connection module for the low-level communication and translates message to
  a easier to use, high-level protocol.
  """

  use Bitwise
  alias BitPal.Backend.Flowee.Connection
  alias BitPal.Backend.Flowee.Connection.Binary
  alias BitPal.Backend.Flowee.Connection.RawMsg

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
  def dummy do
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

  # Get a list of all keys with the same tag.
  defp get_key_list(key, body) do
    case body do
      [{^key, v} | rest] ->
        [v | get_key_list(key, rest)]

      [{_, _} | rest] ->
        get_key_list(key, rest)

      [] ->
        []
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
    Connection.send(c, %RawMsg{service: serviceId, message: messageId, data: data})
  end

  @doc """
  Send a ping to the remote peer. We need to do this about once every minute. Otherwise, we will
  be disconnected after 120 s. It seems it does not matter if we send other data, we will still be
  disconnected if we don't send ping messages.
  """
  def send_ping(c) do
    Connection.send(c, %RawMsg{service: @service_system, ping: true})
  end

  @doc """
  Send a version request message.

  The reply has the format `%Message{type: :version, data: %{version: <string>}}`
  """
  def send_version(c) do
    send_msg(c, @service_api, 0, [])
  end

  @doc """
  Ask for blockchain info. Generates a reply as follows:

  `%Message{type: :info, data: %{blocks: <blocks>, chain: "main", ...}}`
  """
  def send_blockchain_info(c) do
    send_msg(c, @service_blockchain, 0, [])
  end

  @doc """
  Subscribe to get notified of blocks.

  Does not immediately generate a response. Causes the hub to send us block notification messages
  as follows:

  When a new block is found, the following message is sent:
  `%Message{type: :new_block, data: %{hash: <hash>, height: <height>}}`

  When a reorg happens, the following message is sent:
  `%Message{type: :reorg, data: %{hash: <hash>, height: <height>}}`
  """
  def send_block_subscribe(c) do
    send_msg(c, @service_blocknotification, 0, [])
  end

  @doc """
  Unsubscribe to get notified of blocks. Does not generate a reply.
  """
  def send_block_unsubscribe(c) do
    send_msg(c, @service_blocknotification, 2, [])
  end

  # Translate a single output operation.
  defp translate_output_element(output) do
    case output do
      :txid -> {43, true}
      :offset -> {44, true}
      :inputs -> {46, true}
      :outputs -> {49, true}
      :outputScripts -> {48, true}
      :outputAddrs -> {50, true}
      :outputHash -> {51, true}
      :amounts -> {47, true}
    end
  end

  # Get options for the get operation.
  defp get_output(output) do
    Enum.map(output, &translate_output_element/1)
  end

  # Process a single filter.
  defp translate_filter_element(element) do
    case element do
      {:address, hash} ->
        {42, %Binary{data: hash}}
        # more options here...
    end
  end

  # Get filters for the get operation.
  defp get_filters(filters) do
    Enum.map(filters, &translate_filter_element/1)
  end

  @doc """
  Get a block in the blockchain, either based on height or on its hash.

  `outputs` is a list of things to include in the reply:
  - `:txid`: include transaction id
  - `:offset`: include the offset in the block (seems to be done by default at the moment)
  - `:inputs`: include input addresses.
  - `:amounts`: include output amounts.
  - `:outputs`: include all outputs.
  - `:outputScripts`: include output scripts.
  - `:outputAddrs`: include output addresses (for p2pkh or p2pk).
  - `:outputHash`: include script hashes of the outputs (all transactions).

  `filters` is a list of filters to filter the transactions in the requested block.
  - `{:address, <hash>}`: filter transactions based on the output addresses involved.
    Use `Cashaddr.create_hashed_output_script` to generate hashes for an address (the format is
    the same as for subscribing to an address).
  """
  def send_get_block(c, block, outputs, filters \\ [])

  def send_get_block(c, {:height, h}, outputs, filters) do
    send_msg(c, @service_blockchain, 4, [{7, h} | get_filters(filters)] ++ get_output(outputs))
  end

  def send_get_block(c, {:hash, h}, outputs, filters) do
    send_msg(
      c,
      @service_blockchain,
      4,
      [{7, %Binary{data: h}} | get_filters(filters)] ++ get_output(outputs)
    )
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

  @doc """
  Monitor one or more particular addresses. 

  The `address` parameter is a script encoded address. This can be generated from the `BitPal.BCH.CashAddress` module.

  Flowee will send one message when the transaction is first seen:
  `%Message{type: :on_transaction, data: ${txid: <txid>, outputs: [{<address>, <amount>}, ...]}}`

  Flowee then sends another message when it is accepted into a block:
  `%Message{type: :on_transaction, data: ${txid: <txid>, height: <height>, hash: <hash>, outputs: [{<address>, <amount>}, ...]}}`
  """
  def send_address_subscribe(c, address) do
    conv = convert_addresses(address)
    send_msg(c, @service_addressmonitor, 0, conv)
  end

  @doc """
  Stop subscribing to an address.
  """
  def send_address_unsubscribe(c, address) do
    conv = convert_addresses(address)
    send_msg(c, @service_addressmonitor, 2, conv)
  end

  @doc """
  List available indexers.
  """
  def send_find_avail_indexers(c) do
    send_msg(c, @service_indexer, 0, [])
  end

  @doc """
  Find a transaction. Note: Hashes seem to be reversed compared to what is shown on eg. Blockchain Explorer.
  """
  def send_find_transaction(c, bytes) do
    send_msg(c, @service_indexer, 2, [{4, %Binary{data: bytes}}])
  end

  defmodule Message do
    @moduledoc """
    A received high-level message.
    """
    defstruct type: nil, data: %{}
  end

  @doc """
  Helper to make a message from a low-level message.
  """
  def make_msg(type, keys, body) do
    %Message{type: type, data: get_keys(keys, body)}
  end

  @doc """
  Helper to create a message. Does not care if some key is missing.
  """
  def make_msg_opt(type, keys, body) do
    %Message{type: type, data: get_keys_opt(keys, body)}
  end

  @doc """
  Receive some message (blocking). Returns a high-level message.
  """
  def recv(c) do
    %RawMsg{service: service, message: message, data: body} = Connection.recv(c)

    case {service, message} do
      {@service_api, 1} ->
        # Version message
        make_msg(:version, [version: 1], body)

      {@service_blockchain, 1} ->
        # Reply from "blockchain info"
        make_msg(
          :info,
          [
            difficulty: 64,
            median_time: 65,
            chain_work: 66,
            chain: 67,
            blocks: 68,
            headers: 69,
            best_block_hash: 70,
            verification_progress: 71
          ],
          body
        )

      {@service_blockchain, 5} ->
        # Answer to "get block". This requires more intricate parsing...
        %Message{type: :block, data: parse_get_block(body)}

      {@service_blocknotification, 4} ->
        # Notified of a block
        make_msg(:new_block, [hash: 5, height: 7], body)

      {@service_blocknotification, 6} ->
        # Notified of a reorg
        make_msg(:reorg, [hash: 5, height: 7], body)

      {@service_addressmonitor, 1} ->
        # Reply for subscriptions. Note: The documentation is incorrect with the IDs here.
        make_msg_opt(:subscribe_reply, [result: 21, error: 20], body)

      {@service_addressmonitor, 3} ->
        # Sent when an address we monitor is involved in a transaction. Offset is only present when
        # the transaction is accepted in a block.
        %Message{type: :on_transaction, data: parse_on_transaction(body)}

      {@service_addressmonitor, 4} ->
        # Sent when a double-spend is found.
        %Message{type: :on_transaction, data: parse_on_transaction(body)}

      {@service_indexer, 1} ->
        # Indexer reply to what it is indexing.
        make_msg_opt(:available_indexers, [address: 21, transaction: 22, spentOutput: 23], body)

      {@service_indexer, 3} ->
        # Indexer reply to "find transaction"
        make_msg(:transaction, [height: 7, offsetInBlock: 8], body)

      {@service_system, nil} ->
        # Probably a ping response. We don't need to be very fancy.
        %Message{type: :pong}

      _ ->
        # Unknown message!
        raise("Unknown message: #{Kernel.inspect({service, message})} #{Kernel.inspect(body)}")
    end
  end

  # Parse data inside a on transaction message.
  defp parse_on_transaction(body) do
    base = get_keys_opt([txid: 4, height: 7, offset: 8], body)

    addr = get_key_list(9, body)
    amts = get_key_list(6, body)

    Map.put(base, :outputs, List.zip([addr, amts]))
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
        # Note: reverse later?
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

      [{4, id} | rest] ->
        parse_get_transaction(rest, Map.put(data, :txid, id))

      [{20, txid} | rest] ->
        {r, input} = parse_input(rest, %{txid: txid})
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

      [{9, %Binary{data: hash}} | rest] ->
        # Note: This is not in the documentation...
        parse_output(rest, Map.put(data, :outputHash, hash))

      [{6, amount} | rest] ->
        parse_output(rest, Map.put(data, :amount, amount))

      [{23, %Binary{data: script}} | rest] ->
        parse_output(rest, Map.put(data, :outputScript, script))

      [{_, _} | _] ->
        # Some other element we don't recognize. Go back to the caller.
        {body, data}
    end
  end
end
