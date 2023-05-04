defmodule BitPalSchemas.InvoiceRatesTest do
  use ExUnit.Case, async: true
  alias BitPalSchemas.InvoiceRates

  describe "find in rates" do
    setup _tags do
      %{
        rates: %{
          BCH: %{EUR: Decimal.from_float(1.0), USD: Decimal.from_float(2.0)},
          XMR: %{EUR: Decimal.from_float(3.0), USD: Decimal.from_float(4.0)}
        }
      }
    end

    test "find_quote_with_rate", %{rates: rates} do
      assert InvoiceRates.find_quote_with_rate(rates, :BCH) in [
               {:EUR, Decimal.from_float(1.0)},
               {:USD, Decimal.from_float(2.0)}
             ]

      assert InvoiceRates.find_quote_with_rate(rates, :XMR) in [
               {:EUR, Decimal.from_float(3.0)},
               {:USD, Decimal.from_float(4.0)}
             ]

      assert InvoiceRates.find_quote_with_rate(rates, :DGC) == :not_found
    end

    test "find_base_with_rate", %{rates: rates} do
      assert InvoiceRates.find_base_with_rate(rates, :EUR) in [
               {:BCH, Decimal.from_float(1.0)},
               {:XMR, Decimal.from_float(3.0)}
             ]

      assert InvoiceRates.find_base_with_rate(rates, :USD) in [
               {:BCH, Decimal.from_float(2.0)},
               {:XMR, Decimal.from_float(4.0)}
             ]

      assert InvoiceRates.find_base_with_rate(rates, :SEK) == :not_found
    end

    test "has_rate?", %{rates: rates} do
      assert InvoiceRates.has_rate?(rates, :BCH, :USD)
      assert !InvoiceRates.has_rate?(rates, :BCH, :SEK)
      assert !InvoiceRates.has_rate?(rates, :DGC, :USD)
    end
  end
end
