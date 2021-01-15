defmodule Payments.Request do
  defstruct address: nil,
            amount: nil,
            email: "",
            required_confirmations: 0,
            label: "",
            message: ""

  def render_qrcode(request) do
    request
    |> address_with_meta
    |> EQRCode.encode()
    # FIXME need to be able to input styling options here
    |> EQRCode.svg(background_color: "#F5F7FA", viewbox: false, width: 300)
  end

  @doc """
  Encodes amount, label and message into a [BIP-21 URI](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki):

      bitcoin:<address>[?amount=<amount>][?label=<label>][?message=<message>]

  """
  def address_with_meta(request) do
    uri_encode(uri_address(request.address), uri_query(request))
  end

  defp uri_encode(address, ""), do: address
  defp uri_encode(address, query), do: address <> "?" <> query

  defp uri_address(address = "bitcoincash:" <> _), do: address
  defp uri_address(address), do: "bitcoincash:" <> address

  defp uri_query(request) do
    %{"amount" => request.amount, "label" => request.label, "message" => request.message}
    |> encode_query
  end

  @spec encode_query(Enum.t()) :: binary
  def encode_query(enumerable) do
    enumerable
    |> Enum.filter(fn {_key, value} -> value && value != "" end)
    |> Enum.map_join("&", &encode_kv_pair/1)
  end

  defp encode_kv_pair({key, value}) do
    URI.encode(Kernel.to_string(key)) <> "=" <> URI.encode(Kernel.to_string(value))
  end
end
