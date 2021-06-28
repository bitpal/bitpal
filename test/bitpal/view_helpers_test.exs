defmodule BitPal.ViewHelpersTest do
  use ExUnit.Case, async: true
  alias BitPal.ViewHelpers
  alias BitPalSchemas.Invoice

  test "encode address" do
    address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    assert ViewHelpers.address_with_meta(%Invoice{address_id: address}) == address
  end

  test "encode address without prefix" do
    address = "qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    wanted = "bitcoincash:" <> address
    assert ViewHelpers.address_with_meta(%Invoice{address_id: address}) == wanted
  end

  test "endode with amount" do
    address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    amount = Money.parse!(1.337, :BCH)

    assert ViewHelpers.address_with_meta(%Invoice{address_id: address, amount: amount}) ==
             "#{address}?amount=1.337"
  end

  test "endode with amount, label and message" do
    address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"

    assert ViewHelpers.address_with_meta(
             %Invoice{
               address_id: address,
               amount: Money.parse!(1.337, :BCH),
               description: "Thank you for paying tribute!"
             },
             recipent: "BitPalTest"
           ) ==
             "#{address}?amount=1.337&label=BitPalTest&message=Thank%20you%20for%20paying%20tribute!"
  end

  test "encode query" do
    assert ViewHelpers.encode_query(%{
             "a" => nil,
             "b" => 1,
             "hello world" => "foo bar",
             "d" => nil
           }) ==
             "b=1&hello%20world=foo%20bar"
  end
end
