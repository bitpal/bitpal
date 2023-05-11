defmodule BitPal.Backend.MoneroFixtures do
  # monerod fixtures

  def get_info do
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
       "height" => 1_349_905,
       "testnet" => false,
       "top_block_hash" => "4f1956d469d895ca100ad3606a7003776c730ea3553b521c0ee41e9ef3101d6b",
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

  def get_block_count do
    {:ok, %{"count" => 1_349_983, "status" => "OK", "untrusted" => false}}
  end

  def get_version do
    {:ok,
     %{
       "current_height" => 1_349_983,
       "hard_forks" => [
         %{"height" => 1, "hf_version" => 1},
         %{"height" => 32_000, "hf_version" => 2},
         %{"height" => 33_000, "hf_version" => 3},
         %{"height" => 34_000, "hf_version" => 4},
         %{"height" => 35_000, "hf_version" => 5},
         %{"height" => 36_000, "hf_version" => 6},
         %{"height" => 37_000, "hf_version" => 7},
         %{"height" => 176_456, "hf_version" => 8},
         %{"height" => 177_176, "hf_version" => 9},
         %{"height" => 269_000, "hf_version" => 10},
         %{"height" => 269_720, "hf_version" => 11},
         %{"height" => 454_721, "hf_version" => 12},
         %{"height" => 675_405, "hf_version" => 13},
         %{"height" => 676_125, "hf_version" => 14},
         %{"height" => 1_151_000, "hf_version" => 15},
         %{"height" => 1_151_720, "hf_version" => 16}
       ],
       "release" => false,
       "status" => "OK",
       "untrusted" => false,
       "version" => 196_619
     }}
  end

  def sync_info do
    {:ok,
     %{
       "credits" => 0,
       "height" => 1_349_983,
       "next_needed_pruning_seed" => 0,
       "overview" => "[]",
       "peers" => []
     }}
  end

  # monero-wallet-rpc fixtures

  def create_address(index) do
    addresses = [
      %{
        "address" =>
          "7BSZWuzWzdC21DUUe7GsP633YjU9B5VjpA6mngJxLykBhWJy3Zye6QrE8kx2jZHbzDGJFM1qwKyscBKj9toScSF76Bz6qPg",
        "address_index" => 1,
        "address_indices" => [1],
        "addresses" => [
          "7BSZWuzWzdC21DUUe7GsP633YjU9B5VjpA6mngJxLykBhWJy3Zye6QrE8kx2jZHbzDGJFM1qwKyscBKj9toScSF76Bz6qPg"
        ]
      },
      %{
        "address" =>
          "77vB4KhCg4Za8dZsBmpPbZ7yGAT5riypR4KUa2QBe5t7PWuh37hFkYb8MF99esxJg1DpRMo3e92Y1Vf1LaotfLgRHvCLwVE",
        "address_index" => 2,
        "address_indices" => [2],
        "addresses" => [
          "77vB4KhCg4Za8dZsBmpPbZ7yGAT5riypR4KUa2QBe5t7PWuh37hFkYb8MF99esxJg1DpRMo3e92Y1Vf1LaotfLgRHvCLwVE"
        ]
      },
      %{
        "address" =>
          "7BGsmtChJUrKUCk3EuPCsBfFaRNe7vSGJ5oJfPnc3K9v5meaVUyCAumRCCJwfEtRd1QxXktYdc1LFJJKiyav2UUVCUK654R",
        "address_index" => 3,
        "address_indices" => [3],
        "addresses" => [
          "7BGsmtChJUrKUCk3EuPCsBfFaRNe7vSGJ5oJfPnc3K9v5meaVUyCAumRCCJwfEtRd1QxXktYdc1LFJJKiyav2UUVCUK654R"
        ]
      },
      %{
        "address" =>
          "78fEno52zxyG1fpNmCU3QiJH7xReDnsusZ1UsKNLEPVmFaMXeEBEaY8BmksbpsKmm1DKrVg6pbbAcEkr32qM7J6gEBrSTYU",
        "address_index" => 4,
        "address_indices" => [4],
        "addresses" => [
          "78fEno52zxyG1fpNmCU3QiJH7xReDnsusZ1UsKNLEPVmFaMXeEBEaY8BmksbpsKmm1DKrVg6pbbAcEkr32qM7J6gEBrSTYU"
        ]
      },
      %{
        "address" =>
          "75vp9o2ksjsSiwbRXkQxpditaJiNJ3Ytfhgj3SD78zimVKPSqGfZUu3Ti6oE67ek1a1rSFwnRb7LAioA5vui9xAgGjjCy7w",
        "address_index" => 5,
        "address_indices" => [5],
        "addresses" => [
          "75vp9o2ksjsSiwbRXkQxpditaJiNJ3Ytfhgj3SD78zimVKPSqGfZUu3Ti6oE67ek1a1rSFwnRb7LAioA5vui9xAgGjjCy7w"
        ]
      },
      %{
        "address" =>
          "72br8qdco9TAy3DP6C92mqHdq1T6biBgYYxeyYD9HWzSPpjLa8GBogXcX5uXXNHT7Zegb1RSL6yyH4Q1pYu4fEH6NZVzSW6",
        "address_index" => 6,
        "address_indices" => [6],
        "addresses" => [
          "72br8qdco9TAy3DP6C92mqHdq1T6biBgYYxeyYD9HWzSPpjLa8GBogXcX5uXXNHT7Zegb1RSL6yyH4Q1pYu4fEH6NZVzSW6"
        ]
      }
    ]

    {:ok, Enum.at(addresses, index - 1)}
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

  def txid do
    "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666"
  end

  def get_transfer_by_txid do
    # %{account_index: 0, txid: "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666"}
    {:ok,
     %{
       "transfer" => %{
         "address" =>
           "7BSZWuzWzdC21DUUe7GsP633YjU9B5VjpA6mngJxLykBhWJy3Zye6QrE8kx2jZHbzDGJFM1qwKyscBKj9toScSF76Bz6qPg",
         "amount" => 10_000_000_000_000,
         "amounts" => [10_000_000_000_000],
         "double_spend_seen" => false,
         "fee" => 204_880_000,
         "height" => 0,
         "locked" => true,
         "note" => "",
         "payment_id" => "0000000000000000",
         "subaddr_index" => %{"major" => 0, "minor" => 7},
         "subaddr_indices" => [%{"major" => 0, "minor" => 7}],
         "suggested_confirmations_threshold" => 4,
         "timestamp" => 1_683_802_938,
         "txid" => "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666",
         "type" => "pool",
         "unlock_time" => 0
       },
       "transfers" => [
         %{
           "address" =>
             "7BSZWuzWzdC21DUUe7GsP633YjU9B5VjpA6mngJxLykBhWJy3Zye6QrE8kx2jZHbzDGJFM1qwKyscBKj9toScSF76Bz6qPg",
           "amount" => 10_000_000_000_000,
           "amounts" => [10_000_000_000_000],
           "double_spend_seen" => false,
           "fee" => 204_880_000,
           "height" => 0,
           "locked" => true,
           "note" => "",
           "payment_id" => "0000000000000000",
           "subaddr_index" => %{"major" => 0, "minor" => 7},
           "subaddr_indices" => [%{"major" => 0, "minor" => 7}],
           "suggested_confirmations_threshold" => 4,
           "timestamp" => 1_683_802_938,
           "txid" => "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666",
           "type" => "pool",
           "unlock_time" => 0
         }
       ]
     }}
  end

  def get_address(index) do
    {:ok, addresses} = get_address()
    {:ok, Enum.at(addresses["addresses"], index)}
  end

  # https://community.rino.io/faucet/stagenet/
  # Amount sent: 10 XMR
  # Transaction ID: b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666
  # to: 74bqQVMPU15T1MwXnG5Cxk1MkWMNw3NLE6kjtiyLmLmC7cNvELYuseYCGAwwLLZ1o582DG3WmRD5waXgXLst9qA5MUazoLh

  # [notice] notify received: ["monero:tx-notify", "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666"]
  #
  # [notice] get_transfers  %{account_index: 0, failed: true, in: true, pending: true, pool: true, subadd_indices: []}
  # {:ok,
  #  %{
  #  # "out", "pending", "failed", and "pool"
  #    "pool" => [
  #      %{
  #        "address" => "74bqQVMPU15T1MwXnG5Cxk1MkWMNw3NLE6kjtiyLmLmC7cNvELYuseYCGAwwLLZ1o582DG3WmRD5waXgXLst9qA5MUazoLh",
  #        "amount" => 10000000000000,
  #        "amounts" => [10000000000000],
  #        "double_spend_seen" => false,
  #        "fee" => 204880000,
  #        "height" => 0,
  #        "locked" => true,
  #        "note" => "",
  #        "payment_id" => "0000000000000000",
  #        "subaddr_index" => %{"major" => 0, "minor" => 7},
  #        "subaddr_indices" => [%{"major" => 0, "minor" => 7}],
  #        "suggested_confirmations_threshold" => 4,
  #        "timestamp" => 1683802938,
  #        "txid" => "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666",
  #        "type" => "pool",
  #        "unlock_time" => 0
  #      }
  #    ]
  #  }}
  #
  # [notice] make_uri  %{address: "74bqQVMPU15T1MwXnG5Cxk1MkWMNw3NLE6kjtiyLmLmC7cNvELYuseYCGAwwLLZ1o582DG3WmRD5waXgXLst9qA5MUazoLh", amount: 10000000000000}
  # {:ok,
  #  %{
  #    "uri" => "monero:74bqQVMPU15T1MwXnG5Cxk1MkWMNw3NLE6kjtiyLmLmC7cNvELYuseYCGAwwLLZ1o582DG3WmRD5waXgXLst9qA5MUazoLh?tx_amount=10.000000000000"
  #  }}
  #
  # notice] get_balance  %{account_index: 0, adress_indices: []}
  # {:ok,
  #  %{
  #    "balance" => 0,
  #    "blocks_to_unlock" => 0,
  #    "multisig_import_needed" => false,
  #    "time_to_unlock" => 0,
  #    "unlocked_balance" => 0
  #  }}
  #
  #
  # [notice] get_balance  %{account_index: 0, adress_indices: [1]}
  # {:ok,
  #  %{
  #    "balance" => 0,
  #    "blocks_to_unlock" => 0,
  #    "multisig_import_needed" => false,
  #    "time_to_unlock" => 0,
  #    "unlocked_balance" => 0
  #  }}
  #
  # [notice] get_transfer_by_txid  %{account_index: 0, txid: "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666"}
  # {:ok,
  #  %{
  #    "transfer" => %{
  #      "address" => "74bqQVMPU15T1MwXnG5Cxk1MkWMNw3NLE6kjtiyLmLmC7cNvELYuseYCGAwwLLZ1o582DG3WmRD5waXgXLst9qA5MUazoLh",
  #      "amount" => 10000000000000,
  #      "amounts" => [10000000000000],
  #      "confirmations" => 7,
  #      "double_spend_seen" => false,
  #      "fee" => 204880000,
  #      "height" => 1350016,
  #      "locked" => true,
  #      "note" => "",
  #      "payment_id" => "0000000000000000",
  #      "subaddr_index" => %{"major" => 0, "minor" => 7},
  #      "subaddr_indices" => [%{"major" => 0, "minor" => 7}],
  #      "suggested_confirmations_threshold" => 4,
  #      "timestamp" => 1683803346,
  #      "txid" => "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666",
  #      "type" => "in",
  #      "unlock_time" => 0
  #    },
  #    "transfers" => [
  #      %{
  #        "address" => "74bqQVMPU15T1MwXnG5Cxk1MkWMNw3NLE6kjtiyLmLmC7cNvELYuseYCGAwwLLZ1o582DG3WmRD5waXgXLst9qA5MUazoLh",
  #        "amount" => 10000000000000,
  #        "amounts" => [10000000000000],
  #        "confirmations" => 7,
  #        "double_spend_seen" => false,
  #        "fee" => 204880000,
  #        "height" => 1350016,
  #        "locked" => true,
  #        "note" => "",
  #        "payment_id" => "0000000000000000",
  #        "subaddr_index" => %{"major" => 0, "minor" => 7},
  #        "subaddr_indices" => [%{"major" => 0, "minor" => 7}],
  #        "suggested_confirmations_threshold" => 4,
  #        "timestamp" => 1683803346,
  #        "txid" => "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666",
  #        "type" => "in",
  #        "unlock_time" => 0
  #      }
  #    ]
  #  }}
  #
  # [notice] incoming_transfers  %{account_index: 0, subaddr_indices: [], transfer_type: "all"}
  # {:ok,
  #  %{
  #    "transfers" => [
  #      %{
  #        "amount" => 10000000000000,
  #        "block_height" => 1350016,
  #        "frozen" => false,
  #        "global_index" => 6652613,
  #        "key_image" => "",
  #        "pubkey" => "dd0c370520df5c539403a68fc73c8e3d0d2b2110c8f115d9d03b92b7d239c38c",
  #        "spent" => false,
  #        "subaddr_index" => %{"major" => 0, "minor" => 7},
  #        "tx_hash" => "b768029959c15b59330a838bfae1e85adc3f8c812ea1133f5f19f61ab649b666",
  #        "unlocked" => false
  #      }
  #    ]
  #  }}
end

# get_info
#
# get_version
#  %{
#    "release" => false,
#    "status" => "OK",
#    "untrusted" => false,
#    "version" => 196613
#  }
#
