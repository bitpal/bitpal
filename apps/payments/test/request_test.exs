defmodule RequestTest do
  use ExUnit.Case, async: true
  alias Payments.Request
  alias Payments.Address

  test "encode address" do
    address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    assert Request.address_with_meta(%Request{address: address}) == address
  end

  test "encode address without prefix" do
    address = "qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    wanted = "bitcoincash:" <> address
    assert Request.address_with_meta(%Request{address: address}) == wanted
  end

  test "endode with amount" do
    address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    amount = 1.337

    assert Request.address_with_meta(%Request{address: address, amount: amount}) ==
             "#{address}?amount=#{amount}"
  end

  test "endode with amount, label and message" do
    address = "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"
    amount = 1.337
    label = "BitPal"
    message = "Thank you for paying tribute!"

    assert Request.address_with_meta(%Request{
             address: address,
             amount: amount,
             label: label,
             message: message
           }) ==
             "#{address}?amount=#{amount}&label=#{label}&message=Thank%20you%20for%20paying%20tribute!"
  end

  test "encode query" do
    assert Request.encode_query(%{"a" => nil, "b" => 1, "hello world" => "foo bar", "d" => nil}) ==
             "b=1&hello%20world=foo%20bar"
  end

  test "decode address" do
    address = "bitcoincash:qrx5lc6m2wjkqncfzefn49wr3cfvx7l36yderrc7x3"

    wanted =
      {:p2kh,
       <<205, 79, 227, 91, 83, 165, 96, 79, 9, 22, 83, 58, 149, 195, 142, 18, 195, 123, 241, 209>>}

    assert Address.decode_cash_url(address) == wanted
  end
end
