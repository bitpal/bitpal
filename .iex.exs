import Ecto.Query

alias BitPal.Repo
alias BitPal.Invoices
alias BitPal.ExchangeRate
alias BitPal.Currencies
alias BitPalSchemas.Address
alias BitPalSchemas.Currency
alias BitPalSchemas.Invoice
alias Ecto.Multi
import BitPal.NumberHelpers

# Currencies.register!(:BCH)
#
# Invoices.register(%{
#   amount: Money.parse!(1.2, :BCH),
#   exchange_rate: ExchangeRate.new!(Decimal.from_float(1.2), {:BCH, :USD})
# })
