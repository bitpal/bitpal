defmodule BitPalFactory.Utils do
  alias BitPalFactory

  def into_money(money = %Money{}, _currency) do
    money
  end

  def into_money(nil, currency) do
    BitPalFactory.build(:money, currency: currency)
  end

  def into_money(value, currency) do
    with {:ok, dec} <- Decimal.cast(value),
         {:ok, money} <- Money.parse(dec, currency) do
      if money.amount <= 0 do
        exit("""
        Negative money: #{inspect(money)}
        """)
      else
        money
      end
    else
      err ->
        exit("""
        Failed to generate money: #{inspect(err)}
        value: #{inspect(value)}
        currency: #{inspect(currency)}
        """)
    end
  end
end
