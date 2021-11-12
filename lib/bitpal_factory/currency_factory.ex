defmodule BitPalFactory.CurrencyFactory do
  defmacro __using__(_opts) do
    quote do
      alias BitPalFactory.CurrencyGenerator

      @spec unique_currency_id :: Currency.id()
      def unique_currency_id do
        CurrencyGenerator.next_currency_id()
      end

      @spec unique_currency_ids(non_neg_integer) :: [Currency.id()]
      def unique_currency_ids(count) do
        Enum.map(1..count, fn _ ->
          unique_currency_id()
        end)
      end

      @spec unique_fiat :: atom
      def unique_fiat do
        CurrencyGenerator.next_fiat()
      end
    end
  end
end

defmodule BitPalFactory.CurrencyGenerator do
  use GenServer
  use Agent
  alias BitPal.Currencies

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def next_currency_id do
    id = GenServer.call(__MODULE__, {:next_currency_id, :crypto})
    Currencies.ensure_exists!(id)
    id
  end

  def next_fiat do
    GenServer.call(__MODULE__, {:next_currency_id, :fiat})
  end

  @impl true
  def init(_opts) do
    {:ok, %{crypto_count: 0, fiat_count: 0}}
  end

  @impl true
  def handle_call({:next_currency_id, :crypto}, _, state) do
    id_s = "𝓒" <> to_string(state.crypto_count)
    id = String.to_atom(id_s)

    Currencies.add_custom_curreny(id, %{
      name: "Testcrypto #{state.crypto_count}",
      exponent: Faker.random_between(8, 12),
      symbol: id_s
    })

    {:reply, id, %{state | crypto_count: state.crypto_count + 1}}
  end

  @impl true
  def handle_call({:next_currency_id, :fiat}, _, state) do
    id_s = "𝓕 " <> to_string(state.fiat_count)
    id = String.to_atom(id_s)

    Currencies.add_custom_curreny(id, %{
      name: "Testfiat #{state.fiat_count}",
      exponent: 2,
      symbol: id_s
    })

    {:reply, id, %{state | fiat_count: state.fiat_count + 1}}
  end
end
