defmodule BitPal.ExchangeRateTest do
  use ExUnit.Case, async: true
  alias BitPal.ExchangeRate

  test "new" do
    assert :error = ExchangeRate.new(Decimal.new(2), {:USD, :USD})
    assert :error = ExchangeRate.new(Decimal.new(-2), {:BCH, :USD})

    assert {:ok,
            %ExchangeRate{
              rate: Decimal.new(2),
              pair: {:BCH, :USD}
            }} == ExchangeRate.new(Decimal.new(2), {:BCH, :USD})

    assert :error = ExchangeRate.new(Money.parse!(0, "BCH"), Money.parse!(4, "USD"))
    assert :error = ExchangeRate.new(Money.parse!(2, "USD"), Money.parse!(4, "USD"))

    assert {:ok,
            %ExchangeRate{
              rate: Decimal.new(2),
              pair: {:BCH, :USD}
            }} == ExchangeRate.new(Money.parse!(2, "BCH"), Money.parse!(4, "USD"))
  end

  test "normalize" do
    a = Money.parse!(1.2, "BCH")
    b = Money.parse!(2.4, "USD")
    bad_amount = Money.parse!(4.5, "USD")
    bad_currency = Money.parse!(2.4, "EUR")

    rate = %ExchangeRate{
      rate: Decimal.new(2),
      pair: {:BCH, :USD}
    }

    bad_rate = %ExchangeRate{
      rate: Decimal.new(5),
      pair: {:BCH, :USD}
    }

    assert {:ok, ^a, ^b} = ExchangeRate.normalize(rate, a, nil)
    assert {:ok, ^a, ^b} = ExchangeRate.normalize(rate, nil, b)
    assert {:ok, ^a, ^b} = ExchangeRate.normalize(rate, a, b)
    assert {:ok, ^a, ^b} = ExchangeRate.normalize(rate, b, a)
    assert {:error, :bad_params} = ExchangeRate.normalize(rate, nil, nil)
    assert {:error, :bad_params} = ExchangeRate.normalize(rate, a, bad_currency)
    assert {:error, :mismatched_exchange_rate} = ExchangeRate.normalize(bad_rate, a, b)
    assert {:error, :mismatched_exchange_rate} = ExchangeRate.normalize(rate, a, bad_amount)
  end
end
