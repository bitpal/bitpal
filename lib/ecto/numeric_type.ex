defmodule Money.Ecto.NumericType do
  @moduledoc """
  Provides a type for Ecto to store a multi-currency price.

  Based on a NUMERIC data type, as opposed to `Money.Ecto.Composite.Type` that requires an integer type.
  """

  if macro_exported?(Ecto.Type, :__using__, 1) do
    use Ecto.Type
  else
    @behaviour Ecto.Type
  end

  @spec type() :: :money_with_currency
  def type, do: :money_with_currency

  @spec load({Decimal.t(), atom() | String.t()}) :: {:ok, Money.t()} | :error
  def load({amount, currency}) do
    Money.parse(amount, currency)
  end

  @spec dump(any()) :: :error | {:ok, {integer(), String.t()}}
  def dump(money = %Money{}),
    do: {:ok, {Money.to_decimal(money), to_string(money.currency)}}

  def dump(_), do: :error

  @spec cast(Money.t() | {integer(), String.t()} | map() | any()) :: :error | {:ok, Money.t()}
  def cast(money = %Money{}) do
    {:ok, money}
  end

  def cast({amount, currency})
      when is_integer(amount) and (is_binary(currency) or is_atom(currency)) do
    {:ok, Money.new(amount, currency)}
  end

  def cast({amount, currency})
      when is_binary(currency) or is_atom(currency) do
    Money.parse(amount, currency)
  end

  def cast(_), do: :error
end
