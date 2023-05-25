defmodule BitPal.InvoiceAcceptanceTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.InvoiceEvents

  test "accept after no double spend in timeout", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    id = inv.id

    assert [
             {{:invoice, :finalized}, %{id: ^id, status: :open, address_id: _}},
             {{:invoice, :processing}, %{id: ^id, status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{id: ^id}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accept when block is found while waiting for double spend timout", %{
    currency_id: currency_id
  } do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1_000,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accept after a confirmation", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 1}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "confirmed without being seen", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        payment_currency_id: currency_id
      )

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 0}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accepts after multiple confirmations", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 3,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)
    BackendMock.issue_blocks(currency_id, 5)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 3}},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 2}},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 1}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "multiple invoices", %{currency_id: currency_id} do
    {:ok, inv0, stub0, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        expected_payment: Money.parse!(0.1, currency_id),
        required_confirmations: 0
      )

    {:ok, inv1, stub1, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        expected_payment: Money.parse!(1.0, currency_id),
        required_confirmations: 1
      )

    {:ok, inv2, stub2, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        expected_payment: Money.parse!(2.0, currency_id),
        required_confirmations: 2
      )

    inv0_id = inv0.id
    inv1_id = inv1.id
    inv2_id = inv2.id

    BackendMock.tx_seen(inv0)
    BackendMock.tx_seen(inv1)
    HandlerSubscriberCollector.await_msg(stub0, {:invoice, :paid})
    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :processing})

    assert [
             {{:invoice, :finalized}, %{id: ^inv0_id}},
             {{:invoice, :processing}, %{id: ^inv0_id, status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{id: ^inv0_id}}
           ] = HandlerSubscriberCollector.received(stub0)

    assert [
             {{:invoice, :finalized}, %{id: ^inv1_id}},
             {{:invoice, :processing},
              %{id: ^inv1_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, %{id: ^inv2_id}}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.confirmed_in_new_block(inv2)
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :processing})

    assert [
             {{:invoice, :finalized}, %{id: ^inv1_id}},
             {{:invoice, :processing},
              %{id: ^inv1_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, %{id: ^inv2_id}},
             {{:invoice, :processing},
              %{id: ^inv2_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.issue_blocks(currency_id, 2)
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, %{id: ^inv1_id}},
             {{:invoice, :processing},
              %{id: ^inv1_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, %{id: ^inv2_id}},
             {{:invoice, :processing},
              %{id: ^inv2_id, status: {:processing, :confirming}, confirmations_due: 1}},
             {{:invoice, :paid}, %{id: ^inv2_id}}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  test "Invoices of the same amount", %{currency_id: currency_id} do
    inv = [expected_payment: Money.parse!(1.0, currency_id), required_confirmations: 1]

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.expected_payment == inv1.expected_payment
    assert inv0.address_id != inv1.address_id
    assert handler0 != handler1
  end

  test "Detect early 0-conf doublespend", %{currency_id: currency_id} do
    {:ok, inv, stub, _} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :uncollectible})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :uncollectible}, %{status: {:uncollectible, :double_spent}}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "Underpaid invoice", %{currency_id: currency_id} do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        expected_payment: Money.parse!(1.0, currency_id),
        required_confirmations: 0,
        double_spend_timeout: 1
      )

    paid = Money.parse!(0.3, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: paid})

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :underpaid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, %{amount_paid: ^paid}}
           ] = HandlerSubscriberCollector.received(stub)

    paid2 = Money.parse!(0.7, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: paid2})
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    fully_paid = Money.add(paid, paid2)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, %{amount_paid: ^paid}},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{amount_paid: ^fully_paid}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "Overpaid invoice", %{currency_id: currency_id} do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        expected_payment: Money.parse!(1.0, currency_id),
        required_confirmations: 0,
        double_spend_timeout: 1
      )

    amount1 = Money.parse!(0.3, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: amount1})
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :underpaid})

    amount2 = Money.parse!(1.3, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: amount2})
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    total_paid = Money.add(amount1, amount2)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, %{amount_paid: ^amount1}},
             {{:invoice, :overpaid}, %{amount_paid: ^total_paid}},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{amount_paid: ^total_paid}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  describe "reorgs" do
    test "reverse tx to unconfirmed", %{currency_id: currency_id} do
      BackendMock.set_height(currency_id, 10)

      {:ok, inv, stub, _handler} =
        HandlerSubscriberCollector.create_invoice(
          required_confirmations: 3,
          payment_currency_id: currency_id
        )

      # NOTE there's a bit of a race condition hidden here.
      # It doesn't do much other than cause some missing :processing messages if blocks come
      # very quickly, and I haven't been able to make it go away completely,
      # so maybe it's fine to just leave it here?

      InvoiceEvents.subscribe(inv)

      BackendMock.tx_seen(inv)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 0}]}}

      BackendMock.confirmed_in_new_block(inv)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 11}]}}

      BackendMock.issue_blocks(currency_id, 1)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 1, txs: [%{height: 11}]}}

      BackendMock.reverse(inv, new_height: 13)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 0}]}}

      BackendMock.confirmed_in_new_block(inv)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 14}]}}

      BackendMock.issue_blocks(currency_id, 2)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 0}]}},
               {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 1, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 0}]}},
               {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 14}]}},
               {{:invoice, :processing}, %{confirmations_due: 1, txs: [%{height: 14}]}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "reverse tx on split height", %{currency_id: currency_id} do
      BackendMock.set_height(currency_id, 10)

      {:ok, inv, stub, _handler} =
        HandlerSubscriberCollector.create_invoice(
          required_confirmations: 4,
          payment_currency_id: currency_id
        )

      InvoiceEvents.subscribe(inv)

      # confirmed at 11
      BackendMock.confirmed_in_new_block(inv)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 11}]}}

      BackendMock.issue_blocks(currency_id, 1)
      BackendMock.reverse_block(currency_id, new_height: 13, split_height: 11)
      BackendMock.issue_blocks(currency_id, 1)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 1, txs: [%{height: 11}]}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "reverse tx but confirmed in other chain new height", %{currency_id: currency_id} do
      BackendMock.set_height(currency_id, 10)

      {:ok, inv, stub, _handler} =
        HandlerSubscriberCollector.create_invoice(
          required_confirmations: 4,
          payment_currency_id: currency_id
        )

      InvoiceEvents.subscribe(inv)

      # confirmed at 11
      BackendMock.confirmed_in_new_block(inv)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 11}]}}

      BackendMock.issue_blocks(currency_id, 1)
      BackendMock.reverse(inv, new_height: 14, split_height: 10, tx_height: 13)
      BackendMock.issue_blocks(currency_id, 2)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 13}]}},
               {{:invoice, :processing}, %{confirmations_due: 1, txs: [%{height: 13}]}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    # Should force through a :confirmed message even if it's the same height?
    # Via backend.
    test "reverse tx but confirmed in other chain same height", %{currency_id: currency_id} do
      BackendMock.set_height(currency_id, 10)

      {:ok, inv, stub, _handler} =
        HandlerSubscriberCollector.create_invoice(
          required_confirmations: 4,
          payment_currency_id: currency_id
        )

      InvoiceEvents.subscribe(inv)

      # confirmed at 11
      BackendMock.confirmed_in_new_block(inv)

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 11}]}}

      BackendMock.issue_blocks(currency_id, 1)
      BackendMock.reverse(inv, new_height: 12, split_height: 10, tx_height: 11)
      BackendMock.issue_blocks(currency_id, 2)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      # Duplicate message, even though it's in a new chain doesn't show up
      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 2, txs: [%{height: 11}]}},
               {{:invoice, :processing}, %{confirmations_due: 1, txs: [%{height: 11}]}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    # Should be manageable by invoice handler (tx is unchanged)
    test "reverse a block above tx", %{currency_id: currency_id} do
      BackendMock.set_height(currency_id, 10)

      {:ok, inv, stub, _handler} =
        HandlerSubscriberCollector.create_invoice(
          required_confirmations: 3,
          payment_currency_id: currency_id
        )

      BackendMock.tx_seen(inv)
      BackendMock.confirmed_in_new_block(inv)
      BackendMock.issue_blocks(currency_id, 1)
      BackendMock.reverse_block(currency_id)
      BackendMock.issue_blocks(currency_id, 2)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end
  end
end
