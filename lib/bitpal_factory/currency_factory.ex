defmodule BitPalFactory.CurrencyFactory do
  alias BitPal.Blocks
  alias BitPal.Currencies
  alias BitPalFactory.CurrencyCounter
  alias BitPalSchemas.Currency

  def unique_block_id do
    :crypto.hash(:sha256, to_string(System.unique_integer())) |> Base.encode16()
  end

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

  @spec crypto_currency_id([atom]) :: atom
  def crypto_currency_id(blacklist \\ []) do
    Faker.Util.pick([:BCH, :XMR, :DGC], blacklist)
  end

  @spec fiat_currency_id([atom]) :: atom
  def fiat_currency_id(blacklist \\ []) do
    Faker.Util.pick([:USD, :EUR, :SEK], blacklist)
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

    case Blocks.fetch_height(currency_id) do
      :error ->
        height = Faker.random_between(min_height || 1, 100_000)
        Blocks.new(currency_id, height, unique_block_id())
        height

      {:ok, height} ->
        if min_height && height < min_height do
          Blocks.new(currency_id, height, unique_block_id())
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
    id = id_to_atom(id_s)

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
    id = id_to_atom(id_s)

    Currencies.add_custom_curreny(id, %{
      name: "Testfiat #{state.fiat_count}",
      exponent: 2,
      symbol: id_s
    })

    {:reply, id, %{state | fiat_count: state.fiat_count + 1}}
  end

  defp id_to_atom(id) when is_binary(id) do
    # This is fine as atoms are bounded by the number of generated test currencies.
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom(id)
  end
end
