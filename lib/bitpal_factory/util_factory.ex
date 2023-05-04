defmodule BitPalFactory.UtilFactory do
  alias BitPalSchemas.Address

  @spec create_money(atom | Address.t(), map | keyword) :: Money.t()
  def create_money(currency, opts \\ %{})

  def create_money(currency, opts) when is_atom(currency) do
    min = opts[:min] || 1
    max = opts[:max] || 100_000 * (:math.pow(10, Money.Currency.exponent!(currency)) |> round)
    amount = Faker.random_between(min, max)
    Money.new(amount, currency)
  end

  def create_money(address = %Address{}, opts) do
    create_money(address.currency_id, opts)
  end

  @spec rand_pos_float(float) :: float
  def rand_pos_float(max \\ 1.0), do: :rand.uniform() * max

  @spec rand_decimal(float) :: Decimal.t()
  def rand_decimal(max \\ 1_000.0) do
    {:ok, dec} = Decimal.cast(rand_pos_float(max))
    dec
  end

  @spec rand_pos_decimal(keyword) :: Decimal.t()
  def rand_pos_decimal(opts) do
    decimals = opts[:decimals] || nil
    min = Decimal.from_float(opts[:min] || 0.1)
    max = opts[:max] || 1_000.0

    res =
      if decimals do
        Decimal.round(rand_decimal(max), decimals)
      else
        rand_decimal()
      end

    if Decimal.lt?(min, res) do
      res
    else
      min
    end
  end

  @spec split_money(Money.t(), non_neg_integer) :: [Money.t()]
  def split_money(_money = %Money{}, 0), do: []
  def split_money(money = %Money{}, 1), do: [money]

  def split_money(money = %Money{}, n) when n > 1 do
    Stream.repeatedly(fn -> Faker.random_between(1, money.amount) end)
    |> Enum.take(n - 1)
    |> then(fn xs -> [money.amount | xs] end)
    |> Enum.sort()
    # This works by always splitting from the previous value (starting from 0)
    # to the currenct split. This is why it's important that it's sorted.
    |> Enum.reduce({[], 0}, fn split, {res, sum} ->
      next = split - sum
      {[Money.new(next, money.currency) | res], sum + next}
    end)
    |> then(fn {res, _} -> res end)
    # Sometimes we may generate splits at the same value by chance,
    # or if money.amount < n, which may create money of 0 value.
    |> Enum.filter(fn money ->
      money.amount > 0
    end)
  end

  @spec pick([{number, term}], float) :: term
  def pick(xs, selection \\ :rand.uniform()) when is_list(xs) do
    total_prob =
      Enum.reduce(xs, 0, fn {prob, _}, sum ->
        sum + prob
      end)

    if total_prob == 0, do: raise("Cannot pick from 0 prob")

    # First normalize probabilities so they sum up to 1
    Enum.map(xs, fn {prob, val} ->
      {prob / total_prob, val}
    end)
    # Sum up them so their probability is the sum of this and everything before
    |> Enum.reduce({[], 0}, fn {prob, val}, {xs, prob_sum} ->
      next = prob + prob_sum
      {[{next, val} | xs], next}
    end)
    # Throw away sum helper and reverse, so we can find as normal from the beginning
    |> then(fn {xs, _} -> xs end)
    |> Enum.reverse()
    |> Enum.find_value(fn {prob, val} ->
      if selection < prob do
        val
      else
        nil
      end
    end)
  end

  @spec rand_money_lt(Money.t(), non_neg_integer) :: [Money.t()]
  def rand_money_lt(amount, count) do
    split_money(create_money(amount.currency, max: amount.amount - 1), count)
  end

  @spec rand_money_eq(Money.t(), non_neg_integer) :: [Money.t()]
  def rand_money_eq(amount, count) do
    split_money(amount, count)
  end

  @spec rand_money_gt(Money.t(), non_neg_integer) :: [Money.t()]
  def rand_money_gt(amount, count) do
    split_money(
      create_money(amount.currency, min: amount.amount + 1, max: amount.amount * 3),
      count
    )
  end

  # @spec rand_price() :: Money.t()
  # def rand_price() do
  #
  # end
  #
  # def rand_payment
end
