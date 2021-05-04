defmodule InvoiceTest do
  # use ExUnit.Case, async: true
  # alias BitPal.Invoices
  # alias BitPalSchemas.Invoice
  # import Ecto.Changeset
  #
  # test "encode address" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   assert Invoices.address_with_meta(%Invoice{address: address}) == address
  # end
  #
  # test "encode address without prefix" do
  #   address = "qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   wanted = "bitcoincash:" <> address
  #   assert Invoices.address_with_meta(%Invoice{address: address}) == wanted
  # end
  #
  # test "endode with amount" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   amount = 1.337
  #
  #   assert Invoices.address_with_meta(%Invoice{address: address, amount: amount}) ==
  #            "#{address}?amount=#{amount}"
  # end
  #
  # test "endode with amount, label and message" do
  #   address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
  #   amount = 1.337
  #   label = "BitPal"
  #   message = "Thank you for paying tribute!"
  #
  #   assert Invoices.address_with_meta(%Invoice{
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
