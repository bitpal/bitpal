defmodule InvoiceCreationTest do
  use BitPal.DataCase, async: true
  alias BitPal.Invoices
  alias BitPalSchemas.InvoiceRates

  setup do
    store = create_store()
    %{store_id: store.id}
  end

  defp valid_attributes(attrs) do
    Enum.into(attrs, %{
      price: valid_price()
    })
  end

  describe "register/2" do
    test "register price in fiat", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 valid_attributes(price: Money.new(120, :USD))
               )

      assert invoice.id != nil
      assert invoice.price == Money.new(120, :USD)
      assert invoice.payment_currency_id == nil
      assert invoice.rates != nil
      assert InvoiceRates.find_base_with_rate(invoice.rates, :USD) != nil
    end

    test "register price in crypto", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 valid_attributes(price: Money.new(1_000_000_000, :BCH))
               )

      assert invoice.id != nil
      assert invoice.price == Money.new(1_000_000_000, :BCH)
      assert invoice.payment_currency_id == :BCH
      assert invoice.expected_payment == invoice.price
      assert invoice.rates == %{}
    end

    test "register price in crypto and payment", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 valid_attributes(
                   price: Money.new(1_000_000_000, :BCH),
                   payment_currency_id: :BCH
                 )
               )

      assert invoice.id != nil
      assert invoice.price == Money.new(1_000_000_000, :BCH)
      assert invoice.payment_currency_id == :BCH
      assert invoice.expected_payment == invoice.price
    end

    test "no possible exchange rate for fiat", %{store_id: store_id} do
      assert {:error, changeset} =
               Invoices.register(
                 store_id,
                 valid_attributes(price: Money.new(1_000, :AZN))
               )

      assert "unsupported fiat currency without matching exchange rate" in errors_on(changeset).price
    end

    test "no possible exchange rate for fiat/crypto pair", %{store_id: store_id} do
      assert {:error, changeset} =
               Invoices.register(
                 store_id,
                 valid_attributes(
                   price: Money.new(1_000, :USD),
                   rates: %{BCH: %{EUR: Decimal.from_float(1.1)}},
                   payment_currency_id: :BCH
                 )
               )

      assert "could not find rate BCH-USD in %{BCH: %{EUR: #Decimal<1.1>}}" in errors_on(
               changeset
             ).rates
    end

    test "calculates expected_payment", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 valid_attributes(
                   price: Money.parse!(1_000.0, :USD),
                   rates: %{BCH: %{USD: Decimal.from_float(100.0)}},
                   payment_currency_id: :BCH
                 )
               )

      assert invoice.expected_payment == Money.parse!(10.0, :BCH)
    end

    test "basic validations", %{store_id: store_id} do
      assert {:error, changeset} = Invoices.register(store_id, %{})

      assert "must provide a price" in errors_on(changeset).price

      assert {:error, changeset} =
               Invoices.register(
                 store_id,
                 valid_attributes(price: Money.new(-1_000, :USD))
               )

      assert "must be greater than 0" in errors_on(changeset).price
    end

    test "register price in crypto but payment is mismatched", %{store_id: store_id} do
      assert {:error, changeset} =
               Invoices.register(
                 store_id,
                 valid_attributes(
                   price: Money.new(1_000_000_000, :BCH),
                   payment_currency_id: :XMR
                 )
               )

      assert "must be the same as price currency `BCH` when priced in crypto" in errors_on(
               changeset
             ).payment_currency_id
    end

    test "validates payment currency to be a crypto", %{store_id: store_id} do
      assert {:error, changeset} =
               Invoices.register(
                 store_id,
                 valid_attributes(payment_currency_id: :EUR)
               )

      assert "must be a cryptocurrency" in errors_on(changeset).payment_currency_id
    end

    test "register pos info", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 valid_attributes(
                   order_id: "bzztzaxxt",
                   email: "test@bitpal.dev",
                   description: "My awesome invoice",
                   pos_data: %{
                     "some" => "data",
                     "other" => %{"even_more" => 0}
                   }
                 )
               )

      assert invoice.id != nil
      assert invoice.order_id == "bzztzaxxt"
      assert invoice.email == "test@bitpal.dev"
      assert invoice.description == "My awesome invoice"

      assert invoice.pos_data == %{
               "some" => "data",
               "other" => %{"even_more" => 0}
             }
    end

    test "large amounts", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 valid_attributes(price: Money.parse!("127000000000.00000001", :DGC))
               )

      # Need to reload from db to see that bignums are supported properly.
      assert invoice = Invoices.fetch!(invoice.id)
      assert Money.to_decimal(invoice.price) == Decimal.new("127000000000.00000001")

      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 price: Money.parse!("10000000000000000", :USD),
                 rates: %{
                   DGC: %{USD: Decimal.new("0.1")}
                 },
                 payment_currency_id: :DGC
               })

      assert invoice.expected_payment == Money.parse!("100000000000000000", :DGC)
    end

    test "override exchange rates", %{store_id: store_id} do
      rates = %{
        BCH: %{
          USD: Decimal.new("1.2"),
          EUR: Decimal.new("1.6")
        },
        XMR: %{
          USD: Decimal.new("1.0"),
          EUR: Decimal.new("1.9")
        }
      }

      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 price: Money.new(100, :USD),
                 rates: rates
               })

      assert invoice = Invoices.fetch!(invoice.id)
      assert invoice.rates == rates
    end

    test "invald rates if they don't contain pairs", %{store_id: store_id} do
      assert {:error, changeset} =
               Invoices.register(store_id, %{
                 price: Money.new(100, :USD),
                 rates: %{BCH: %{SEK: Decimal.new("1.2")}}
               })

      assert "could not find rate with USD in %{BCH: %{SEK: #Decimal<1.2>}}" in errors_on(
               changeset
             ).rates

      assert {:error, changeset} =
               Invoices.register(store_id, %{
                 price: Money.new(100, :USD),
                 payment_currency_id: :XMR,
                 rates: %{BCH: %{USD: Decimal.new("1.2")}}
               })

      assert "could not find rate XMR-USD in %{BCH: %{USD: #Decimal<1.2>}}" in errors_on(
               changeset
             ).rates
    end

    test "validates rates", %{store_id: store_id} do
      invalid = [
        "1.2",
        %{
          USD: Decimal.new("1.2")
        },
        %{
          BCH: %{
            USD: "xxx"
          }
        },
        %{
          BCH: %{
            USD: Decimal.new("-1.2")
          }
        },
        %{
          BCH: %{
            USD: Decimal.new("0")
          }
        }
      ]

      for x <- invalid do
        assert {:error, _} =
                 Invoices.register(store_id, %{
                   price: Money.new(100, :USD),
                   rates: x
                 })
      end
    end
  end
end
