defmodule BitPal.Invoice do
  @type currency :: atom
  @type address :: String.t()
  @type t :: %__MODULE__{
          address: address,
          # FIXME should be a BaseUnit
          amount: Decimal.t(),
          currency: currency,
          exchange_rate: Decimal.t(),
          fiat_amount: Decimal.t(),
          email: String.t(),
          required_confirmations: non_neg_integer,
          label: String.t(),
          message: String.t()
        }

  defstruct address: nil,
            amount: nil,
            currency: :bch,
            exchange_rate: nil,
            fiat_amount: nil,
            email: "",
            required_confirmations: 0,
            label: "",
            message: ""

  @spec id(t) :: binary
  def id(invoice) do
    # FIXME generate and store from db
    Decimal.to_string(invoice.amount, :normal)
  end

  def render_qrcode(request, opts \\ []) do
    request
    |> address_with_meta
    |> EQRCode.encode()
    |> EQRCode.svg(opts)
  end

  @doc """
  Encodes amount, label and message into a [BIP-21 URI](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki):

      bitcoin:<address>[?amount=<amount>][?label=<label>][?message=<message>]

  """
  @spec address_with_meta(t) :: address
  def address_with_meta(invoice) do
    uri_encode(uri_address(invoice.address), uri_query(invoice))
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
