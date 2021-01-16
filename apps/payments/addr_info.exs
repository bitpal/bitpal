alias Payments.Connection
alias Payments.Protocol
alias Payments.Address

# c = Connection.connect(1234)
# Protocol.send_find_avail_indexers(c)
# IO.inspect(Protocol.recv(c))
# Protocol.send_find_transaction(c, transId)
# IO.inspect(Protocol.recv(c))
# Connection.close(c)

# transId =
#   Address.hex_to_binary("89cce90204447b218b996975868a29d8a5460de1346dbd07cbc16a3a7dc500eb")

# c = Connection.connect()

# Protocol.send_get_block(c, {:height, 670_468}, [
#   :transactionId,
#   :inputs,
#   :outputs,
#   :amounts,
#   :outputAddrs
# ])

# transactions = Protocol.recv(c).data[:transactions]
# t = Enum.find(transactions, fn x -> x[:transactionId] === transId end)
# IO.puts("ID: " <> Address.binary_to_hex(t.transactionId))
# IO.puts("Address: " <> Address.binary_to_hex(Enum.at(t.outputs, 1).address))
# IO.inspect(t)

# Perhaps the address is this?
addr = Address.decode_cash_url("bitcoincash:qrx5lc6m2wjkqncfzefn49wr3cfvx7l36yderrc7x3")
IO.inspect(addr)
Payments.Node.watch_wallet(addr)

# Payments.Node.watch_wallet(addr)

# c = Connection.connect()
# Protocol.send_address_subscribe(c, addr)
# IO.inspect(Protocol.recv(c))
# Connection.close(c)
