defmodule AddressTest do
  use BitPal.IntegrationCase
  alias BitPal.Addresses
  alias BitPal.Currencies
  alias BitPal.Invoices

  setup do
    Currencies.register!([:xmr, :bch])
  end

  test "address registration" do
    assert {:ok, _} = Addresses.register(:bch, "bch:main", nil)
    assert {:ok, _} = Addresses.register(:bch, [{"bch:0", 0}, {"bch:1", 1}])
    assert {:ok, _} = Addresses.register("BCH", "bch:2", 2)

    assert {:error, changeset} = Addresses.register("BCH", "bch:2", 20)
    assert "has already been taken" in errors_on(changeset).id

    # Cannot reuse address indexes
    assert {:error, changeset} = Addresses.register("BCH", "unique", 0)
    assert "has already been taken" in errors_on(changeset).generation_index

    # Reuse index is ok for other cryptos
    assert {:ok, _} = Addresses.register(:xmr, [{"xmr:0", 0}, {"xmr:1", 1}])
    assert {:ok, _} = Addresses.register(:xmr, "xmr:2", 2)
  end

  test "next address" do
    assert 0 == Addresses.next_address_index(:bch)

    {:ok, _} = Addresses.register(:bch, [{"bch:0", 0}, {"bch:1", 1}])
    assert 2 == Addresses.next_address_index(:bch)
    assert 0 == Addresses.next_address_index(:xmr)
  end

  test "unused address" do
    assert {:ok, _} = Addresses.register(:bch, [{"bch:0", 0}, {"bch:1", 1}])
    assert {:ok, _} = Addresses.register(:xmr, [{"xmr:0", 0}, {"xmr:1", 1}])

    a1 = Addresses.find_unused_address(:bch)
    assert a1 != nil

    assign_address(a1)
    a2 = Addresses.find_unused_address(:bch)
    assert a2 != nil
    assert a2 != a1

    assign_address(a2)
    assert Addresses.find_unused_address(:bch) == nil

    assert Addresses.find_unused_address(:xmr) != nil
    assert Addresses.find_unused_address("no") == nil
  end

  defp assign_address(address) do
    assert {:ok, invoice} =
             Invoices.register(%{currency: :bch, amount: 1.2, exchange_rate: {1.1, "USD"}})

    assert {:ok, _} = Invoices.assign_address(invoice, address)
  end
end
