# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BitPal.Repo.insert!(%BitPal.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Just playing around a bit

# import Ecto.Query
#
# # alias Ecto.Multi
# alias BitPal.Repo
# alias BitPal.{Invoices, Currencies, Addresses}
# alias BitPalSchemas.{Address, Currency, Invoice}
#
# from("invoices") |> Repo.delete_all()
# from("addresses") |> Repo.delete_all()
# from("currencies") |> Repo.delete_all()
#
# Currencies.register!([:XMR, :BCH])
#
# 1. Ensure tests passes
# 2. Track invoices in handler
# 4. Track status updates
# 5. Exchange rate data for invoice
# 6. Update inferface and demo app
# 3. Ensure that handler can recover from crash
