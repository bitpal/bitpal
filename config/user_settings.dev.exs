# config :bitpal, :currencies,
#   BCH: %{
#     xpub:
#       "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7",
#     min_amount: 0.00001,
#     double_spend_timeout: 2_000,
#     required_confirmations: 0
#   },
#   XMR: %{
#     address:
#       "496YrjKKenbYS6KCfPabsJ11pTkikW79ZDDrkPDTC79CSTdCoubgh3f5BrupzBvPLWXNjjNsY8smmFDYvgVRQDsmCT5FhCU",
#     viewkey: "805b4f767bdc7774a5c5ae2b3b8981c53646fff952f92de1ff749cf922e26d0f",
#     required_confirmations: 1
#   }
#
# config :bitpal, BitPal.Backend.Monero,
#   # 18081 for mainnet, 28081 for testnet and 38081 for stagenet
#   net: :stagenet,
#   daemon_ip: "localhost",
#   daemon_port: 38081,
#   wallet_port: 8332
#
# config :bitpal, BitPal.BackendManager,
#   restart_timeout: 3_000,
#   backends: [
#     BitPal.Backend.Flowee,
#     BitPal.Backend.Monero
#   ]
#
# config :bitpal, BitPal.ExchangeRate,
#   sources: [
#     {BitPal.ExchangeRate.Sources.Kraken, prio: 100},
#     {BitPal.ExchangeRate.Sources.Coinbase, prio: 50},
#     {BitPal.ExchangeRate.Sources.Coingecko, prio: 0}
#   ]
