defmodule BitPal.RenderHelpers do
  alias BitPal.Currencies

  def put_unless_nil(map, _key, nil), do: map
  def put_unless_nil(map, key, val), do: Map.put(map, key, val)

  def put_unless_nil(map, _key, nil, fun) when is_function(fun, 1), do: map

  def put_unless_nil(map, key, val, fun) when is_function(fun, 1) do
    Map.put(map, key, fun.(val))
  end

  def put_unless_false(map, key, val), do: put_unless(map, key, val, false)

  def put_unless(map, _key, val, val), do: map
  def put_unless(map, key, val, _skip), do: Map.put(map, key, val)

  def put_unless_empty(map, key, val) do
    if Enum.empty?(val) do
      map
    else
      Map.put(map, key, val)
    end
  end

  def format_expected_payment(invoice) do
    invoice.expected_payment |> money_to_string()
  end

  def format_price(invoice) do
    invoice.price |> money_to_string()
  end

  def money_to_string(money) do
    Money.to_string(money, money_format_args(money.currency))
  end

  def money_format_args(:SEK) do
    [separator: "", delimiter: ".", symbol_space: true, symbol_on_right: true]
  end

  def money_format_args(id) do
    if Currencies.is_crypto(id) do
      [symbol_space: true, symbol_on_right: true, strip_insignificant_zeros: true]
    else
      []
    end
  end
end
