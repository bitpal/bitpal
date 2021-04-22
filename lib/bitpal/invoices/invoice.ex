defmodule BitPal.Invoice do
  import Ecto.Changeset
  require Decimal

  @type currency :: atom
  @type address :: String.t()
  @type t :: %__MODULE__{
          address: address,
          amount: Decimal.t(),
          currency: currency,
          exchange_rate: Decimal.t(),
          fiat_amount: Decimal.t(),
          email: String.t(),
          required_confirmations: non_neg_integer(),
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

  @spec create(map | list) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def create(params) do
    params |> changeset |> apply_action(:create)
  end

  def merge_changeset(changeset, params \\ [])

  def merge_changeset(changeset, params) when is_list(params) do
    merge_changeset(changeset, Enum.into(params, %{}))
  end

  def merge_changeset(changeset, params) when is_map(params) and is_struct(changeset.data) do
    invoice_changeset =
      Map.merge(params, Map.from_struct(apply_changes(changeset)))
      |> changeset()

    merge(changeset, invoice_changeset)
  end

  def merge_changeset(changeset, params) when is_map(params) and is_map(changeset.data) do
    invoice_changeset =
      Map.merge(params, apply_changes(changeset))
      |> changeset()

    # Merging requires that they have the same type
    changeset = %{changeset | data: struct(BitPal.Invoice, changeset.data)}

    snd_type_merge(changeset, invoice_changeset)
  end

  defp snd_type_merge(cs1, cs2) do
    %{merge(cs1, cs2) | types: cs2.types}
  end

  def changeset(params) when is_list(params) do
    changeset(Enum.into(params, %{}))
  end

  def changeset(params) when is_map(params) do
    permitted = %{
      address: :binary,
      # Would be nice to say 'Decimal' type
      amount: :any,
      exchange_rate: :any,
      fiat_amount: :any,
      # Would like an `:atom` here, but it doesn't exist?
      currency: :any,
      email: :string,
      required_confirmations: :integer,
      label: :string,
      message: :string
    }

    {%BitPal.Invoice{}, permitted}
    |> cast(params, Map.keys(permitted))
    |> validate_into_decimal(:amount)
    |> validate_into_decimal(:exchange_rate)
    |> validate_into_decimal(:fiat_amount)
    |> validate_amounts()
    |> validate_format(:email, ~r/^.+@.+$/, message: "Must be a valid email")
    |> validate_number(:required_confirmations, greater_than_or_equal_to: 0)
    |> validate_required(:address)
    |> validate_required(:currency)
  end

  defp validate_into_decimal(changeset, key) do
    changeset
    |> update_change(key, fn
      x when is_float(x) -> Decimal.from_float(x) |> Decimal.normalize()
      x when is_number(x) or is_bitstring(x) -> Decimal.new(x)
      x -> x
    end)
    |> validate_change(key, fn ^key, val ->
      if Decimal.is_decimal(val) do
        []
      else
        [{key, "must be a number"}]
      end
    end)
  end

  defp validate_amounts(changeset) do
    amount = get_field(changeset, :amount)
    exchange_rate = get_field(changeset, :exchange_rate)
    fiat_amount = get_field(changeset, :fiat_amount)

    # IO.puts("amount #{amount} rate #{exchange_rate} fiat #{fiat_amount}")

    cond do
      !exchange_rate ->
        add_error(changeset, :exchange_rate, "must provide an exchange rate")

      amount && fiat_amount ->
        if Decimal.eq?(Decimal.mult(amount, exchange_rate), fiat_amount) do
          changeset
        else
          add_error(changeset, :fiat_amount, "fiat amount != amount * exchange rate")
        end

      !fiat_amount ->
        change(changeset, fiat_amount: Decimal.mult(amount, exchange_rate))

      !amount ->
        change(changeset, amount: Decimal.div(fiat_amount, exchange_rate))

      true ->
        changeset
    end
  end

  @spec id(t) :: binary
  def id(invoice) do
    Decimal.to_string(Decimal.normalize(invoice.amount), :normal)
  end

  def render_qrcode(invoice, opts \\ []) do
    invoice
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
