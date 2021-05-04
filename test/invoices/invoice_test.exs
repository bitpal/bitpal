defmodule InvoiceTest do
  # use ExUnit.Case, async: true
  # alias BitPal.Invoices
  # import Ecto.Changeset

  # this should all be moved or thrown out

  # test "invoice creation" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #
  #   {:ok, invoice} =
  #     Invoices.create(
  #       address: address,
  #       email: "test@bitpal.dev",
  #       amount: 1.337,
  #       exchange_rate: 2.0,
  #       required_confirmations: 1
  #     )
  #
  #   assert invoice.amount == Decimal.from_float(1.337)
  #   assert invoice.exchange_rate == Decimal.new(2)
  #   assert invoice.fiat_amount == Decimal.from_float(2.674)
  #
  #   {:ok, invoice} =
  #     Invoices.create(
  #       address: address,
  #       exchange_rate: 2,
  #       fiat_amount: 1.2
  #     )
  #
  #   assert invoice.amount == Decimal.from_float(0.6)
  # end
  #
  # @tag do: true
  # test "invoice changeset" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #
  #   [fiat_amount: _] =
  #     Invoices.changeset(address: address, amount: 1, exchange_rate: 2, fiat_amount: 5555).errors
  #
  #   [exchange_rate: _] = Invoices.changeset(address: address, amount: 1, fiat_amount: 2).errors
  #
  #   [address: _] = Invoices.changeset(amount: 1, exchange_rate: 2).errors
  #
  #   # Changeset chaining
  #   c =
  #     {%{}, %{amount: :float, exchange_rate: :float}}
  #     |> cast(%{amount: 1, exchange_rate: 2}, [:amount, :exchange_rate])
  #     |> Invoices.merge_changeset(%{address: address})
  #
  #   assert c.valid?
  #   assert c.changes.amount == Decimal.new(1)
  #   assert c.changes.exchange_rate == Decimal.new(2)
  #   assert c.changes.fiat_amount == Decimal.new(2)
  #
  #   c =
  #     {%Invoices{}, %{amount: :float}}
  #     |> cast(%{}, [:amount])
  #     |> validate_required(:amount, message: "amount_error")
  #     |> Invoices.merge_changeset()
  #
  #   # Keeps errors from previous changeset
  #   [amount: {"amount_error", _}, address: _, exchange_rate: _] = c.errors
  #
  #   c =
  #     {%{}, %{amount: :float}}
  #     |> cast(%{amount: 5.0}, [:amount])
  #     |> Invoices.merge_changeset(%{address: address, exchange_rate: 1.5})
  #
  #   assert c.valid?
  #   assert c.changes.amount == Decimal.new(5)
  #   assert c.changes.exchange_rate == Decimal.from_float(1.5)
  #   assert c.changes.fiat_amount == Decimal.from_float(7.5)
  #
  #   {:ok, invoice} = apply_action(c, :setup)
  #   assert invoice.amount == Decimal.new(5)
  #   assert invoice.exchange_rate == Decimal.from_float(1.5)
  #   assert invoice.fiat_amount == Decimal.from_float(7.5)
  # end

  # test "encode address" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   assert Invoices.address_with_meta(%Invoices{address: address}) == address
  # end
  #
  # test "encode address without prefix" do
  #   address = "qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   wanted = "bitcoincash:" <> address
  #   assert Invoices.address_with_meta(%Invoices{address: address}) == wanted
  # end
  #
  # test "endode with amount" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   amount = 1.337
  #
  #   assert Invoices.address_with_meta(%Invoices{address: address, amount: amount}) ==
  #            "#{address}?amount=#{amount}"
  # end
  #
  # test "endode with amount, label and message" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   amount = 1.337
  #   label = "BitPal"
  #   message = "Thank you for paying tribute!"
  #
  #   assert Invoices.address_with_meta(%Invoices{
  #            address: address,
  #            amount: amount,
  #            label: label,
  #            message: message
  #          }) ==
  #            "#{address}?amount=#{amount}&label=#{label}&message=Thank%20you%20for%20paying%20tribute!"
  # end
  #
  # test "encode query" do
  #   assert Invoices.encode_query(%{"a" => nil, "b" => 1, "hello world" => "foo bar", "d" => nil}) ==
  #            "b=1&hello%20world=foo%20bar"
  # end
end
