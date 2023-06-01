defmodule BitPal.PaymentUri do
  @doc """
  Encode an invoice with transformation mappings.
  """
  @type encode_params :: %{
          prefix: String.t(),
          decimal_amount_key: String.t(),
          description_key: String.t(),
          recipient_name_key: String.t()
        }

  @spec encode_invoice(Invoice.t(), encode_params) :: String.t()
  def encode_invoice(invoice, %{
        prefix: prefix,
        decimal_amount_key: amount_key,
        description_key: description_key,
        recipient_name_key: recipient_name_key
      }) do
    query_params = %{
      amount_key => Decimal.to_string(Money.to_decimal(invoice.expected_payment), :normal),
      description_key => invoice.description,
      recipient_name_key => invoice.store.recipient_name
    }

    encode_address_with_meta(prefix, invoice.address_id, query_params)
  end

  @doc """
  Encode an address with metadata to a payment uri.

  Can be used to encode using [BIP-21 URI](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki):

       <prefix>:<address>[?amount=<amount>][?label=<label>][?message=<message>]

  """
  def encode_address_with_meta(prefix, address, query_params \\ []) do
    uri = uri_encode(address, encode_query(query_params))

    cond do
      String.starts_with?(address, prefix <> ":") ->
        uri

      prefix == "" ->
        uri

      true ->
        prefix <> ":" <> uri
    end
  end

  defp uri_encode(address, ""), do: address
  defp uri_encode(address, query), do: address <> "?" <> query

  defp encode_query(params) do
    params
    |> Enum.filter(fn {_key, value} -> value && value != "" end)
    |> Enum.map_join("&", &encode_kv_pair/1)
  end

  defp encode_kv_pair({key, value}) do
    URI.encode(Kernel.to_string(key)) <> "=" <> URI.encode(Kernel.to_string(value))
  end
end
