defmodule BitPal.ViewHelpers do
  alias BitPalSchemas.Invoice

  @spec money_to_string(Money.t()) :: String.t()
  def money_to_string(money) do
    Money.to_string(money,
      strip_insignificant_zeros: true,
      symbol_on_right: true,
      symbol_space: true
    )
  end

  @spec render_qrcode(Invoice.t(), keyword) :: binary
  def render_qrcode(invoice, opts \\ []) do
    invoice
    |> address_with_meta(opts)
    |> EQRCode.encode()
    |> EQRCode.svg(opts)
  end

  @doc """
  Encodes amount, label and message into a [BIP-21 URI](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki):

      bitcoin:<address>[?amount=<amount>][?label=<label>][?message=<message>]

  """
  @spec address_with_meta(Invoice.t(), keyword) :: String.t()
  def address_with_meta(invoice, opts \\ []) do
    recipent =
      Keyword.get(opts, :recipent) || Application.get_env(:bitpal, :recipent_description, "")

    uri_encode(uri_address(invoice.address_id), uri_query(invoice, recipent))
  end

  @spec uri_encode(String.t(), String.t()) :: String.t()
  defp uri_encode(address, ""), do: address
  defp uri_encode(address, query), do: address <> "?" <> query

  @spec uri_address(String.t()) :: String.t()
  defp uri_address(address = "bitcoincash:" <> _), do: address
  defp uri_address(address), do: "bitcoincash:" <> address

  @spec uri_query(Invoice.t(), String.t()) :: String.t()
  defp uri_query(invoice, recipent) do
    %{
      "amount" =>
        if invoice.amount do
          Decimal.to_string(Money.to_decimal(invoice.amount), :normal)
        else
          nil
        end,
      "label" => recipent,
      "message" => invoice.description
    }
    |> encode_query
  end

  @spec encode_query(Enum.t()) :: String.t()
  def encode_query(enumerable) do
    enumerable
    |> Enum.filter(fn {_key, value} -> value && value != "" end)
    |> Enum.map_join("&", &encode_kv_pair/1)
  end

  defp encode_kv_pair({key, value}) do
    URI.encode(Kernel.to_string(key)) <> "=" <> URI.encode(Kernel.to_string(value))
  end
end
