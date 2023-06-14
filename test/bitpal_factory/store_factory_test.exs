defmodule BitPalFactory.StoreFactoryTest do
  use BitPal.IntegrationCase, async: true
  alias BitPalSchemas.InvoiceStatus

  setup tags do
    Map.put(tags, :store, create_store())
  end

  describe "with_token/2" do
    setup tags = %{store: store} do
      store =
        store
        |> with_token(Map.take(tags, [:label, :data]))
        |> Repo.preload(:access_tokens)

      %{tags | store: store}
    end

    @tag label: "My token", data: "token_data"
    test "override data", %{store: store} do
      [token] = store.access_tokens
      assert token.data == "token_data"
      assert token.label == "My token"
    end
  end

  describe "with_invoices/2" do
    setup tags = %{store: store} do
      if tags[:manual] do
        tags
      else
        store =
          store
          |> with_invoices(
            Map.take(tags, [:invoice_count, :payment_currencies, :payment_currency_id, :txs])
          )

        %{tags | store: store}
      end
    end

    @tag manual: true
    test "override currency_id", %{store: store} do
      currency_id = unique_currency_id()
      store = with_invoices(store, payment_currency_id: currency_id)

      for invoice <- store.invoices do
        assert invoice.payment_currency_id == currency_id
      end
    end

    @tag manual: true
    test "pick from currencies", %{store: store} do
      currencies = unique_currency_ids(2)

      store = with_invoices(store, payment_currencies: currencies)

      for invoice <- store.invoices do
        assert invoice.payment_currency_id in currencies
      end
    end

    @tag invoice_count: 3
    test "set invoice count", %{store: store} do
      assert Enum.count(store.invoices) == 3
    end

    @tag txs: :auto, invoice_count: 10
    test "autogenerate txs", %{store: store} do
      # Can have txs in other configurations, this is to avoid false positives.
      have_txs =
        Enum.any?(store.invoices, fn invoice ->
          InvoiceStatus.state(invoice.status) in [:paid, :processing]
        end)

      # Should be true in most cases, just have this check to avoid possible failure
      if have_txs do
        tx_count =
          Enum.reduce(store.invoices, 0, fn invoice, sum ->
            sum + Enum.count(Repo.preload(invoice, :tx_outputs).tx_outputs)
          end)

        assert tx_count > 0
      end
    end
  end
end
