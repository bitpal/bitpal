defmodule BitPal.InvoiceUpdateTest do
  use BitPal.DataCase, async: true
  alias BitPal.Stores
  alias BitPal.Invoices
  alias BitPalSettings.ExchangeRateSettings

  setup tags do
    tags = Map.put_new(tags, :status, :draft)
    %{invoice: create_invoice(tags)}
  end

  describe "update/2" do
    @tag status: :open
    test "cannot change a finalized invoice", %{invoice: invoice} do
      assert {:error, :finalized} = Invoices.update(invoice, %{email: "new_mail@bitpal.dev"})
    end

    test "update aux data", %{invoice: invoice} do
      {:ok, update} =
        Invoices.update(invoice, %{
          description: "new description",
          email: "new_mail@bitpal.dev",
          order_id: "new_order_id",
          pos_data: %{
            "the_answer" => 42
          }
        })

      assert update.description == "new description"
      assert update.email == "new_mail@bitpal.dev"
      assert update.order_id == "new_order_id"

      assert update.pos_data == %{
               "the_answer" => 42
             }
    end

    test "change price", %{invoice: invoice} do
      rate = Invoices.rate!(invoice)
      new_price = Money.parse!(1.0, invoice.price.currency)

      {:ok, update} = Invoices.update(invoice, %{price: new_price})

      assert update.price == new_price

      assert update.expected_payment ==
               Money.parse!(
                 Decimal.div(Money.to_decimal(new_price), rate),
                 invoice.payment_currency_id
               )
    end

    test "change price currency", %{invoice: invoice} do
      new_currency = fiat_currency_id([invoice.price.currency])

      {:ok, update} =
        Invoices.update(invoice, %{
          price: Money.new(invoice.price.amount, new_currency)
        })

      new_rate = update.rates[update.payment_currency_id][new_currency]
      assert new_rate != Invoices.rate!(invoice)

      assert update.price.amount == invoice.price.amount
      assert update.price.currency == new_currency

      assert update.expected_payment ==
               Money.parse!(
                 Decimal.div(Money.to_decimal(update.price), new_rate),
                 invoice.payment_currency_id
               )
    end

    test "change price in crypto", %{invoice: invoice} do
      new_currency = crypto_currency_id()
      new_price = Money.parse!(2.0, new_currency)

      {:ok, update} =
        Invoices.update(invoice, %{
          price: new_price,
          payment_currency_id: new_currency
        })

      assert update.price == new_price
      assert update.expected_payment == new_price
    end

    @tag payment_currency_id: :BCH, price: Money.parse!(2.0, :USD)
    test "change rates", %{invoice: invoice} do
      new_rate = Decimal.from_float(6.0)

      new_rates = %{
        BCH: %{
          USD: new_rate
        }
      }

      {:ok, update} =
        Invoices.update(invoice, %{
          rates: new_rates
        })

      assert update.expected_payment ==
               Money.parse!(
                 Decimal.div(Decimal.from_float(2.0), new_rate),
                 :BCH
               )
    end

    @tag payment_currency_id: :BCH, price: Money.parse!(2.0, :USD)
    test "change rates must contain fiat/crypto pairs", %{invoice: invoice} do
      new_rate = Decimal.from_float(6.0)

      new_rates = %{
        BCH: %{
          EUR: new_rate
        }
      }

      {:error, changeset} =
        Invoices.update(invoice, %{
          rates: new_rates
        })

      assert "could not find rate BCH-USD in %{BCH: %{EUR: Decimal.new(\"6.0\")}}" in errors_on(
               changeset
             ).rates

      new_rates = %{
        XMR: %{
          USD: new_rate
        }
      }

      {:error, changeset} =
        Invoices.update(invoice, %{
          rates: new_rates
        })

      assert "could not find rate BCH-USD in %{XMR: %{USD: Decimal.new(\"6.0\")}}" in errors_on(
               changeset
             ).rates
    end

    test "change payment currency", %{invoice: invoice} do
      new_currency = crypto_currency_id([invoice.payment_currency_id])
      assert new_currency != invoice.payment_currency_id

      {:ok, update} =
        Invoices.update(invoice, %{
          payment_currency_id: new_currency
        })

      new_rate = update.rates[new_currency][invoice.price.currency]
      assert new_rate != Invoices.rate!(invoice)

      assert update.payment_currency_id == new_currency

      assert update.expected_payment ==
               Money.parse!(
                 Decimal.div(Money.to_decimal(update.price), new_rate),
                 new_currency
               )
    end

    test "basic validations", %{invoice: invoice} do
      assert {:error, changeset} =
               Invoices.update(
                 invoice,
                 %{
                   price: nil
                 }
               )

      assert "must provide a price" in errors_on(changeset).price

      assert {:error, changeset} =
               Invoices.update(
                 invoice,
                 %{
                   price: Money.new(-1_000, :USD)
                 }
               )

      assert "must be greater than 0" in errors_on(changeset).price
    end

    test "change price in crypto but payment is mismatched", %{invoice: invoice} do
      new_currency = crypto_currency_id([invoice.payment_currency_id])
      assert new_currency != invoice.payment_currency_id

      {:error, changeset} =
        Invoices.update(invoice, %{
          price: Money.parse!(2.0, new_currency)
        })

      assert "must be the same as price currency `#{new_currency}` when priced in crypto" in errors_on(
               changeset
             ).payment_currency_id
    end

    test "validates payment currency to be a crypto", %{invoice: invoice} do
      {:error, changeset} =
        Invoices.update(invoice, %{
          payment_currency_id: :USD
        })

      assert "must be a cryptocurrency" in errors_on(changeset).payment_currency_id
    end
  end

  describe "finalize/1" do
    test "required fields", %{invoice: invoice} do
      # Manually override to bypass register/update validations.
      {:error, changeset} =
        Invoices.finalize(%{
          invoice
          | address_id: nil,
            price: nil,
            rates: nil,
            payment_currency_id: nil,
            required_confirmations: nil,
            payment_uri: nil
        })

      assert "can't be blank" in errors_on(changeset).address_id
      assert "can't be blank" in errors_on(changeset).price
      assert "can't be blank" in errors_on(changeset).rates
      assert "can't be blank" in errors_on(changeset).payment_currency_id
      assert "can't be blank" in errors_on(changeset).required_confirmations
      assert "can't be blank" in errors_on(changeset).payment_uri
    end

    @tag payment_currency_id: :BCH,
         price: Money.parse!(2.0, :USD),
         address_id: :auto,
         payment_uri: "uri"
    test "updates rates if they don't contain fiat/crypto pairs", %{invoice: invoice} do
      new_rate = Decimal.from_float(6.0)

      new_rates = %{BCH: %{EUR: new_rate}}
      {:ok, updated} = Invoices.finalize(%{invoice | rates: new_rates})
      assert updated.rates != new_rates

      new_rates = %{XMR: %{USD: new_rate}}
      {:ok, updated} = Invoices.finalize(%{invoice | rates: new_rates})
      assert updated.rates != new_rates
    end

    @tag payment_currency_id: :BCH,
         price: Money.parse!(2.0, :USD),
         address_id: :auto,
         payment_uri: "uri",
         rates: %{BCH: %{USD: Decimal.from_float(1.0)}}
    test "leaves rates if recent", %{invoice: invoice} do
      {:ok, updated} = Invoices.finalize(invoice)
      assert invoice.rates == updated.rates
    end

    @tag payment_currency_id: :BCH,
         price: Money.parse!(2.0, :USD),
         address_id: :auto,
         payment_uri: "uri",
         rates: %{BCH: %{USD: Decimal.from_float(1.0)}}
    test "updates rates if too old", %{invoice: invoice} do
      now = NaiveDateTime.utc_now()
      ttl = ExchangeRateSettings.rates_ttl()
      expired = NaiveDateTime.add(now, -ttl - 1, :millisecond)
      {:ok, updated} = Invoices.finalize(%{invoice | rates_updated_at: expired})
      assert invoice.rates != updated.rates
    end

    test "price in crypto but payment is mismatched", %{invoice: invoice} do
      {:error, changeset} =
        Invoices.finalize(%{
          invoice
          | price: Money.parse!(2.0, :BCH),
            payment_currency_id: :XMR
        })

      assert "must be the same as price currency `BCH` when priced in crypto" in errors_on(
               changeset
             ).payment_currency_id
    end

    test "validates payment currency to be a crypto", %{invoice: invoice} do
      {:error, changeset} =
        Invoices.finalize(%{
          invoice
          | payment_currency_id: :USD
        })

      assert "must be a cryptocurrency" in errors_on(changeset).payment_currency_id
    end

    @tag payment_uri: "uri"
    test "requires an address", %{invoice: invoice} do
      assert invoice.address_id == nil

      {:ok, invoice} =
        Invoices.finalize(%{
          invoice
          | address_id: unique_address_id()
        })

      assert invoice.address_id != nil
      assert invoice.payment_currency_id != nil
      assert invoice.expected_payment != nil
      assert invoice.rates != nil
    end

    @tag address_id: :auto, payment_uri: "uri"
    test "calculates expected_payment", %{invoice: invoice} do
      # We shouldn't really do this (updating other info),
      # but it's an easier test to create.
      {:ok, invoice} =
        Invoices.finalize(%{
          invoice
          | price: Money.parse!(6.0, :USD),
            payment_currency_id: :BCH,
            rates: %{BCH: %{USD: Decimal.from_float(3.0)}}
        })

      assert invoice.expected_payment == Money.parse!(Decimal.from_float(2.0), :BCH)
    end
  end

  describe "basic transitions" do
    @tag status: :open
    test "uncollectible", %{invoice: invoice} do
      x = Invoices.double_spent!(invoice)
      assert x.status == {:uncollectible, :double_spent}

      x = Invoices.expire!(invoice)
      assert x.status == {:uncollectible, :expired}

      x = Invoices.cancel!(invoice)
      assert x.status == {:uncollectible, :canceled}

      x = Invoices.timeout!(invoice)
      assert x.status == {:uncollectible, :timed_out}

      x = Invoices.failed!(invoice)
      assert x.status == {:uncollectible, :failed}
    end

    @tag status: {:uncollectible, :expired}
    test "void uncollectible", %{invoice: invoice} do
      {:ok, invoice} = Invoices.void(invoice)
      assert invoice.status == {:void, :expired}
    end

    @tag status: :open
    test "void open", %{invoice: invoice} do
      {:ok, invoice} = Invoices.void(invoice)
      assert invoice.status == :void
    end

    @tag address_id: :auto, status: :open, required_confirmations: 0
    test "verifying", %{invoice: invoice} do
      invoice = Invoices.process!(invoice)
      assert invoice.status == {:processing, :verifying}
    end

    @tag address_id: :auto, status: :open, required_confirmations: 3
    test "confirming", %{invoice: invoice} do
      invoice = Invoices.process!(invoice)
      assert invoice.status == {:processing, :confirming}
    end
  end

  describe "delete/1" do
    @tag status: :draft
    test "delete a draft", %{invoice: invoice} do
      {:ok, _} = Invoices.fetch(invoice.id)
      {:ok, _} = Invoices.delete(invoice)
      {:error, :not_found} = Invoices.fetch(invoice.id)
    end

    @tag status: :open
    test "cannot delete an opened invoice", %{invoice: invoice} do
      {:error, :finalized} = Invoices.delete(invoice)
      {:ok, _} = Invoices.fetch(invoice.id)
    end
  end

  describe "assign_payment_uri/2" do
    setup tags = %{invoice: invoice} do
      store = Stores.fetch!(invoice.store_id)
      {:ok, store} = Stores.update(store, %{recipient_name: tags[:recipient_name] || ""})
      invoice = %{invoice | store: store}
      %{invoice: invoice}
    end

    @tag recipient_name: "The awesome store"
    @tag status: :open
    test "with recipient description", %{invoice: invoice} do
      Invoices.assign_payment_uri(invoice, %{
        prefix: "x",
        decimal_amount_key: "amount",
        description_key: "descr",
        recipient_name_key: "rec"
      })

      invoice = Invoices.fetch!(invoice.id)
      assert String.contains?(invoice.payment_uri, "rec=" <> URI.encode("The awesome store"))
    end

    @tag recipient_name: ""
    @tag status: :open
    test "without recipient description", %{invoice: invoice} do
      Invoices.assign_payment_uri(invoice, %{
        prefix: "x",
        decimal_amount_key: "amount",
        description_key: "descr",
        recipient_name_key: "recipient_name"
      })

      invoice = Invoices.fetch!(invoice.id)
      refute String.contains?(invoice.payment_uri, "recipient_name")
    end

    @tag status: :open, payment_currency_id: :BCH, price: Money.parse!(1.0, :BCH)
    test "format amount", %{invoice: invoice} do
      Invoices.assign_payment_uri(invoice, %{
        prefix: "x",
        decimal_amount_key: "amount",
        description_key: "descr",
        recipient_name_key: "recipient_name"
      })

      invoice = Invoices.fetch!(invoice.id)
      assert String.contains?(invoice.payment_uri, "amount=1.0")
    end

    @tag status: :open, description: "My description"
    test "other keys", %{invoice: invoice} do
      Invoices.assign_payment_uri(invoice, %{
        prefix: "x",
        decimal_amount_key: "amount",
        description_key: "descr",
        recipient_name_key: "recipient_name"
      })

      invoice = Invoices.fetch!(invoice.id)
      assert String.contains?(invoice.payment_uri, URI.encode("My description"))
    end
  end
end
