defmodule AddressTest do
  use BitPal.IntegrationCase
  alias BitPal.Addresses
  alias BitPal.ExchangeRate
  alias BitPal.Invoices

  test "address registration" do
    assert {:ok, _} = Addresses.register(:BCH, "bch:main", nil)
    assert {:ok, _} = Addresses.register(:BCH, [{"bch:0", 0}, {"bch:1", 1}])
    assert {:ok, _} = Addresses.register(:BCH, "bch:2", 2)

    assert {:error, changeset} = Addresses.register(:BCH, "bch:2", 20)
    assert "has already been taken" in errors_on(changeset).id

    # Cannot reuse address indexes
    assert {:error, changeset} = Addresses.register(:BCH, "unique", 0)
    assert "has already been taken" in errors_on(changeset).generation_index

    # Reuse index is ok for other cryptos
    assert {:ok, _} = Addresses.register(:XMR, [{"xmr:0", 0}, {"xmr:1", 1}])
    assert {:ok, _} = Addresses.register(:XMR, "xmr:2", 2)
  end

  test "next address" do
    assert 0 == Addresses.next_address_index(:BCH)

    {:ok, _} = Addresses.register(:BCH, [{"bch:0", 0}, {"bch:1", 1}])
    assert 2 == Addresses.next_address_index(:BCH)
    assert 0 == Addresses.next_address_index(:XMR)
  end

  test "unused address" do
    assert {:ok, _} = Addresses.register(:BCH, [{"bch:0", 0}, {"bch:1", 1}])
    assert {:ok, _} = Addresses.register(:XMR, [{"xmr:0", 0}, {"xmr:1", 1}])

    a1 = Addresses.find_unused_address(:BCH)
    assert a1 != nil

    assign_address(a1)
    a2 = Addresses.find_unused_address(:BCH)
    assert a2 != nil
    assert a2 != a1

    assign_address(a2)
    assert Addresses.find_unused_address(:BCH) == nil

    assert Addresses.find_unused_address(:XMR) != nil
    assert Addresses.find_unused_address(:no) == nil
  end

  defp assign_address(address) do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, :BCH),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {:BCH, :USD})
             })

    assert {:ok, _} = Invoices.assign_address(invoice, address)
  end
end
