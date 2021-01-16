alias Payments.Connection
alias Payments.Protocol
alias Payments.Address

transId =
  Address.hex_to_binary("89cce90204447b218b996975868a29d8a5460de1346dbd07cbc16a3a7dc500eb")

IO.inspect(transId)

# c = Connection.connect(1234)
# Protocol.send_find_avail_indexers(c)
# IO.inspect(Protocol.recv(c))
# Protocol.send_find_transaction(c, hash)
# IO.inspect(Protocol.recv(c))
# Connection.close(c)

# Note: This does not work since we get a too large message back.
c = Connection.connect()

Protocol.send_get_block(c, {:height, 670_468}, [
  :transactionId,
  :inputs,
  :outputs,
  :amounts,
  :outputAddrs
])

transactions = Protocol.recv(c).data[:transactions]
t = Enum.find(transactions, fn x -> x[:transactionId] === transId end)
IO.puts(Address.binary_to_hex(t.transactionId))
IO.inspect(t)

# IO.inspect(Address.decodeCashUrl("bitcoincash:qpz06hwgawrqlwrxvgmz6cm0emurcgmlw5zygrnc0g"))
# addr =
#   Address.createHashedOutputScript(
#     <<0x02, 0x2B, 0xFD, 0x04, 0x25, 0x17, 0x2D, 0xDB, 0xF3, 0xC4, 0x6E, 0x29, 0x55, 0xC6, 0xCD,
#       0x72, 0x74, 0xFB, 0x1A, 0xD1, 0x12, 0xD3, 0x5C, 0x14, 0xA0, 0x49, 0x3B, 0x4E, 0x8E, 0x61,
#       0x6D, 0xED, 0x88>>
#     # <<0x03, 0xA8, 0x8A, 0xBA, 0x3D, 0xF0, 0xCA, 0x37, 0x72, 0xE0, 0x7A, 0x64, 0x9B, 0xDE, 0xE6,
#     #   0xE2, 0x49, 0x26, 0x27, 0xDB, 0xD9, 0x60, 0x1E, 0x70, 0x83, 0x8D, 0x84, 0xB5, 0x93, 0xF3,
#     #   0x3B, 0x6C, 0xFC>>
#   )

# Payments.Node.watch_wallet(addr)

# c = Connection.connect()
# Protocol.send_address_subscribe(c, addr)
# IO.inspect(Protocol.recv(c))
# Connection.close(c)
