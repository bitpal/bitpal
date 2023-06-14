defmodule BitPal.Backend.BCHNFixtures do
  alias BitPalFactory.CurrencyFactory

  def getnetworkinfo do
    {:ok,
     %{
       "connections" => 8,
       "excessutxocharge" => 0.0,
       "localaddresses" => [],
       "localrelay" => true,
       "localservices" => "0000000000000425",
       "networkactive" => true,
       "networks" => [
         %{
           "limited" => false,
           "name" => "ipv4",
           "proxy" => "",
           "proxy_randomize_credentials" => false,
           "reachable" => true
         }
       ],
       "protocolversion" => 70_016,
       "relayfee" => 0.00005,
       "subversion" => "/Bitcoin Cash Node:26.1.0(EB32.0)/",
       "timeoffset" => -2,
       "version" => 26_010_000,
       "warnings" => "This is a pre-release test build"
     }}
  end

  def createwallet do
    # There's some things here, but we don't use them
    {:ok, %{}}
  end

  def getblockchaininfo(opts \\ []) do
    height = opts[:height] || 796_760
    hash = opts[:hash] || CurrencyFactory.unique_block_id()
    progress = opts[:progress] || 0.9999990587256142

    {:ok,
     %{
       "bestblockhash" => hash,
       "blocks" => height,
       "chain" => "main",
       "chainwork" => "000000000000000000000000000000000000000001bcd650ce5a939671463ef6",
       "difficulty" => 196_754_175_089.4261,
       "headers" => height,
       "initialblockdownload" => false,
       "mediantime" => 1_686_549_185,
       "pruned" => false,
       "size_on_disk" => 215_191_879_957,
       "verificationprogress" => progress,
       "warnings" => "This is a pre-release test build"
     }}
  end

  def listsinceblock(opts \\ []) do
    {:ok,
     %{
       "transactions" => listsinceblock_txs(opts[:txs] || []),
       "removed" => listsinceblock_txs(opts[:removed] || [])
     }}
  end

  defp listsinceblock_txs(txs) when is_list(txs) do
    Enum.map(txs, &listsinceblock_txs/1)
  end

  defp listsinceblock_txs(opts) do
    opts = Map.new(opts)

    address = Map.fetch!(opts, :address)
    txid = Map.fetch!(opts, :txid)
    amount = convert_amount(opts[:amount] || 0.1)
    confirmations = opts[:confirmations] || 0

    %{
      "address" => address,
      "category" => "receive",
      "amount" => amount,
      "vout" => 1,
      "fee" => 0.00005,
      "confirmations" => confirmations,
      "blockhash" => "blockhash",
      "blockindex" => 0,
      "blocktime" => 132_456_789,
      "txid" => txid,
      "time" => 132_456_789,
      "timereceived" => 132_456_789,
      "abandoned" => false,
      "comment" => "",
      "label" => "",
      "to" => ""
    }
  end

  def gettransaction(opts \\ []) do
    address = Keyword.fetch!(opts, :address)
    txid = Keyword.fetch!(opts, :txid)
    amount = convert_amount(opts[:amount] || 0.1)
    confirmations = opts[:confirmations] || 0

    {:ok,
     %{
       "amount" => amount,
       "confirmations" => confirmations,
       "details" => [
         %{
           "address" => address,
           "amount" => amount,
           "category" => "receive",
           "involvesWatchonly" => true,
           "label" => "",
           "vout" => 0
         }
       ],
       "hex" =>
         "01000000013cf268da29a45fab65960ec5a223bc6e4905fc87bb68028c99b1a5762bac37a1000000006441c22996d9408ca422ea1d6c2bbd877a1627072d56ebbb0f83b38ab7fdd88e415f36e3a95d7e8431325f36aed546b5714d1a7f51f6848c187489463309258be57e412102cb28341ad2efa48370b8c200c7a9a46c4bc978b2529737fd11070f7ee81a36d9feffffff0210270000000000001976a9148924161865c22d00e6c5822427b57b6b5ec816c088aca4b92900000000001976a91459ca1fcddb23170864dc01fa7b072bc11381d22e88ac88280c00",
       "time" => 1_686_576_490,
       "timereceived" => 1_686_576_490,
       "trusted" => false,
       "txid" => txid,
       "walletconflicts" => []
     }}
  end

  def listreceivedbyaddress(txs) do
    {:ok,
     Enum.map(txs, fn tx_opts ->
       opts = Map.new(tx_opts)

       address = Map.fetch!(opts, :address)
       txid = Map.fetch!(opts, :txid)

       amount =
         Map.fetch!(opts, :amount)
         |> convert_amount()

       confirmations = Map.fetch!(opts, :confirmations)

       %{
         "address" => address,
         "amount" => amount,
         "confirmations" => confirmations,
         "involvesWatchonly" => true,
         "label" => "",
         "txids" => [txid]
       }
     end)}
  end

  defp convert_amount(x = %Money{}), do: convert_amount(Money.to_decimal(x))
  defp convert_amount(x = %Decimal{}), do: Decimal.to_float(x)
  defp convert_amount(x) when is_float(x), do: x
end
