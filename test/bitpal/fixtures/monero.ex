defmodule BitPal.Backend.MoneroFixtures do
  alias BitPalFactory.CurrencyFactory

  def get_info(opts \\ []) do
    height = opts[:height] || 1_349_905
    hash = opts[:hash] || CurrencyFactory.unique_block_id()

    {:ok,
     %{
       "stagenet" => true,
       "was_bootstrap_ever_used" => false,
       "synchronized" => true,
       "busy_syncing" => false,
       "bootstrap_daemon_address" => "",
       "offline" => false,
       "status" => "OK",
       "top_hash" => "",
       "white_peerlist_size" => 34,
       "block_size_median" => 300_000,
       "untrusted" => false,
       "mainnet" => false,
       "database_size" => 4_446_515_200,
       "difficulty" => 373_492,
       "rpc_connections_count" => 2,
       "credits" => 0,
       "nettype" => "stagenet",
       "target_height" => 0,
       "wide_difficulty" => "0x5b2f4",
       "start_time" => 1_683_787_398,
       "version" => "0.18.1.2-unknown",
       "wide_cumulative_difficulty" => "0x46327bd126",
       "adjusted_time" => 1_683_787_472,
       "block_size_limit" => 600_000,
       "cumulative_difficulty" => 301_494_685_990,
       "update_available" => true,
       "tx_pool_size" => 0,
       "outgoing_connections_count" => 12,
       "target" => 120,
       "block_weight_median" => 300_000,
       "height_without_bootstrap" => 1_349_905,
       "cumulative_difficulty_top64" => 0,
       "height" => height,
       "testnet" => false,
       "top_block_hash" => hash,
       "difficulty_top64" => 0,
       "grey_peerlist_size" => 998,
       "block_weight_limit" => 600_000,
       "tx_count" => 1_195_654,
       "incoming_connections_count" => 0,
       "alt_blocks_count" => 0,
       "restricted" => false,
       "free_space" => 399_861_395_456
     }}
  end

  def get_block_count(opts \\ []) do
    height = opts[:height] || 1_349_905
    {:ok, %{"count" => height, "status" => "OK", "untrusted" => false}}
  end

  def daemon_get_version do
    {
      :ok,
      %{
        "release" => false,
        "status" => "OK",
        "untrusted" => false,
        "version" => 196_613
      }
    }
  end

  def sync_info(opts \\ []) do
    height = opts[:height] || 1_349_905
    target_height = opts[:target_height] || 0

    {:ok,
     %{
       "credits" => 0,
       "height" => height,
       "next_needed_pruning_seed" => 0,
       "overview" => "[mooooooooo.oooo..]",
       "peers" => [],
       "spans" => [],
       "status" => "OK",
       "target_height" => target_height,
       "top_hash" => "",
       "untrusted" => false
     }}
  end

  # monero-wallet-rpc fixtures

  def wallet_get_version do
    {:ok, %{"version" => 65_539}}
  end

  def get_height(opts \\ []) do
    height = opts[:height] || 1_349_905

    {:ok, %{"height" => height}}
  end

  def addresses do
    [
      "7BSZWuzWzdC21DUUe7GsP633YjU9B5VjpA6mngJxLykBhWJy3Zye6QrE8kx2jZHbzDGJFM1qwKyscBKj9toScSF76Bz6qPg",
      "77vB4KhCg4Za8dZsBmpPbZ7yGAT5riypR4KUa2QBe5t7PWuh37hFkYb8MF99esxJg1DpRMo3e92Y1Vf1LaotfLgRHvCLwVE",
      "7BGsmtChJUrKUCk3EuPCsBfFaRNe7vSGJ5oJfPnc3K9v5meaVUyCAumRCCJwfEtRd1QxXktYdc1LFJJKiyav2UUVCUK654R",
      "78fEno52zxyG1fpNmCU3QiJH7xReDnsusZ1UsKNLEPVmFaMXeEBEaY8BmksbpsKmm1DKrVg6pbbAcEkr32qM7J6gEBrSTYU",
      "75vp9o2ksjsSiwbRXkQxpditaJiNJ3Ytfhgj3SD78zimVKPSqGfZUu3Ti6oE67ek1a1rSFwnRb7LAioA5vui9xAgGjjCy7w",
      "72br8qdco9TAy3DP6C92mqHdq1T6biBgYYxeyYD9HWzSPpjLa8GBogXcX5uXXNHT7Zegb1RSL6yyH4Q1pYu4fEH6NZVzSW6"
    ]
  end

  def create_address(opts \\ []) do
    index = opts[:index] || 1
    address = opts[:address] || Enum.at(addresses(), index - 1)

    {:ok,
     %{
       "address" => address,
       "address_index" => index,
       "address_indices" => [index],
       "addresses" => [
         address
       ]
     }}
  end

  def get_accounts do
    {:ok,
     %{
       "subaddress_accounts" => [
         %{
           "account_index" => 0,
           "balance" => 0,
           "base_address" =>
             "53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru",
           "label" => "Primary account",
           "tag" => "",
           "unlocked_balance" => 0
         }
       ],
       "total_balance" => 0,
       "total_unlocked_balance" => 0
     }}
  end

  def get_address do
    {:ok,
     %{
       "address" =>
         "53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru",
       "addresses" => [
         %{
           "address" =>
             "53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru",
           "address_index" => 0,
           "label" => "Primary account",
           "used" => false
         },
         %{
           "address" =>
             "7BSZWuzWzdC21DUUe7GsP633YjU9B5VjpA6mngJxLykBhWJy3Zye6QrE8kx2jZHbzDGJFM1qwKyscBKj9toScSF76Bz6qPg",
           "address_index" => 1,
           "label" => "",
           "used" => false
         },
         %{
           "address" =>
             "77vB4KhCg4Za8dZsBmpPbZ7yGAT5riypR4KUa2QBe5t7PWuh37hFkYb8MF99esxJg1DpRMo3e92Y1Vf1LaotfLgRHvCLwVE",
           "address_index" => 2,
           "label" => "",
           "used" => false
         },
         %{
           "address" =>
             "7BGsmtChJUrKUCk3EuPCsBfFaRNe7vSGJ5oJfPnc3K9v5meaVUyCAumRCCJwfEtRd1QxXktYdc1LFJJKiyav2UUVCUK654R",
           "address_index" => 3,
           "label" => "",
           "used" => false
         },
         %{
           "address" =>
             "78fEno52zxyG1fpNmCU3QiJH7xReDnsusZ1UsKNLEPVmFaMXeEBEaY8BmksbpsKmm1DKrVg6pbbAcEkr32qM7J6gEBrSTYU",
           "address_index" => 4,
           "label" => "",
           "used" => false
         },
         %{
           "address" =>
             "75vp9o2ksjsSiwbRXkQxpditaJiNJ3Ytfhgj3SD78zimVKPSqGfZUu3Ti6oE67ek1a1rSFwnRb7LAioA5vui9xAgGjjCy7w",
           "address_index" => 5,
           "label" => "",
           "used" => false
         },
         %{
           "address" =>
             "72br8qdco9TAy3DP6C92mqHdq1T6biBgYYxeyYD9HWzSPpjLa8GBogXcX5uXXNHT7Zegb1RSL6yyH4Q1pYu4fEH6NZVzSW6",
           "address_index" => 6,
           "label" => "",
           "used" => false
         }
       ]
     }}
  end

  defp txinfo(opts) do
    opts = Map.new(opts)

    amount = opts[:amount] || 10_000_000
    height = opts[:height] || 1_349_905
    double_spend = opts[:double_spend] || false
    unlock_time = opts[:unlock_time] || 0
    address = Map.fetch!(opts, :address)
    txid = Map.fetch!(opts, :txid)

    %{
      "address" => address,
      "amount" => amount,
      "amounts" => [amount],
      "double_spend_seen" => double_spend,
      "fee" => 204_880_000,
      "height" => height,
      "locked" => true,
      "note" => "",
      "payment_id" => "0000000000000000",
      "subaddr_index" => %{"major" => 0, "minor" => 7},
      "subaddr_indices" => [%{"major" => 0, "minor" => 7}],
      "suggested_confirmations_threshold" => 4,
      "timestamp" => 1_683_802_938,
      "txid" => txid,
      "type" => "pool",
      "unlock_time" => unlock_time
    }
  end

  def get_transfer_by_txid(opts \\ []) do
    txinfo = txinfo(opts)

    {:ok,
     %{
       "transfer" => txinfo,
       "transfers" => [txinfo]
     }}
  end

  def get_address(index) do
    {:ok, addresses} = get_address()
    {:ok, Enum.at(addresses["addresses"], index)}
  end

  def get_transfers(txs \\ []) do
    {:ok,
     %{
       "in" => Enum.map(txs, &txinfo/1)
     }}
  end
end
