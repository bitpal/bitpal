defmodule BitPalFactory.UtilFactoryTest do
  use BitPal.IntegrationCase, async: true
  import BitPalFactory.UtilFactory

  describe "pick/1" do
    test "pick regular" do
      assert pick([{0.3, :a}, {0.7, :b}]) in [:a, :b]
      assert pick([{3, :a}, {7, :b}]) in [:a, :b]
      assert pick([{3, :a}, {7, :b}, {10, :c}]) in [:a, :b, :c]
    end

    test "pick edge values" do
      values = [{0.001, :a}, {0.9, :b}, {0.099, :c}]
      assert pick(values, 0) == :a
      assert pick(values, 0.0009) == :a
      assert pick(values, 0.001) == :b
      assert pick(values, 0.900) == :b
      assert pick(values, 0.901) == :c
      assert pick(values, 0.99999) == :c
    end
  end

  describe "split_money/2" do
    test "sum to initial" do
      for count <- 1..5 do
        total = Faker.random_between(10, 100)

        gotten_sum =
          split_money(Money.new(total, :USD), count)
          |> sum()

        assert gotten_sum == total
      end
    end

    test "not enough splits" do
      for amount <- 1..3 do
        moneys = split_money(Money.new(amount, :USD), 10)
        assert sum(moneys) == amount

        for money <- moneys do
          assert money.amount > 0
        end
      end
    end

    defp sum(moneys) do
      Enum.reduce(moneys, 0, fn money, sum ->
        sum + money.amount
      end)
    end
  end

  describe "rand_money" do
    setup %{currency_id: currency_id} do
      %{money: Money.new(Faker.random_between(10, 1_000_000_000_000), currency_id)}
    end

    test "rand_money_lt/2", %{money: money} do
      [got] = rand_money_lt(money, 1)
      assert got.currency == money.currency
      assert got.amount > 0 && got.amount < money.amount

      [fst, snd] = rand_money_lt(money, 2)
      assert fst.currency == money.currency
      assert snd.currency == money.currency
      assert fst.amount > 0
      assert snd.amount > 0
      assert fst.amount + snd.amount < money.amount
    end

    test "rand_money_eq/2", %{money: money} do
      [got] = rand_money_eq(money, 1)
      assert got.currency == money.currency
      assert got.amount == money.amount

      [fst, snd] = rand_money_eq(money, 2)
      assert fst.currency == money.currency
      assert snd.currency == money.currency
      assert fst.amount > 0
      assert snd.amount > 0
      assert fst.amount + snd.amount == money.amount
    end

    test "rand_money_gt/2", %{money: money} do
      [got] = rand_money_gt(money, 1)
      assert got.currency == money.currency
      assert got.amount > money.amount

      [fst, snd] = rand_money_gt(money, 2)
      assert fst.currency == money.currency
      assert snd.currency == money.currency
      assert fst.amount > 0
      assert snd.amount > 0
      assert fst.amount + snd.amount > money.amount
    end
  end
end
