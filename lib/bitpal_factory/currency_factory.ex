defmodule BitPalFactory.CurrencyFactory do
  alias BitPalFactory.CurrencyCounter
  alias BitPal.Currencies
  alias BitPalSchemas.Currency

  @spec unique_currency_id :: Currency.id()
  def unique_currency_id do
    CurrencyCounter.next_currency_id()
  end

  @spec unique_currency_ids(non_neg_integer) :: [Currency.id()]
  def unique_currency_ids(count) do
    Stream.repeatedly(&unique_currency_id/0)
    |> Enum.take(count)
  end

  @spec unique_fiat :: atom
  def unique_fiat do
    CurrencyCounter.next_fiat()
  end

  @spec fiat_currency([atom]) :: String.t()
  def fiat_currency(blacklist \\ []) do
    Faker.Util.pick(["USD", "EUR", "SEK"], blacklist)
  end

  @spec get_or_create_currency_id(map) :: Currency.id()
  def get_or_create_currency_id(%{currency_id: currency_id}), do: currency_id

  def get_or_create_currency_id(%{currency: currency_id}) when is_atom(currency_id) do
    currency_id
  end

  def get_or_create_currency_id(_), do: unique_currency_id()

  def block_height(currency_id, opts \\ %{}) do
    min_height = opts[:min]

    case Currencies.fetch_height(currency_id) do
      :error ->
        height = Faker.random_between(min_height || 1, 100_000)
        Currencies.set_height!(currency_id, height)
        height

      {:ok, height} ->
        if min_height && height < min_height do
          Currencies.set_height!(currency_id, min_height)
          min_height
        else
          height
        end
    end
  end
end

defmodule BitPalFactory.CurrencyCounter do
  use GenServer
  alias BitPal.Currencies
  # alias BitPalFactory.CurrencyFactory

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def next_currency_id do
    id = GenServer.call(__MODULE__, {:next_currency_id, :crypto})
    # CurrencyFactory.create_currency(id)
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
