defmodule BitPal.Currencies do
  import Ecto.Query, only: [from: 2]
  alias BitPal.Repo
  alias BitPalSchemas.Currency

  @type ticker :: atom | String.t()

  def get(nil), do: nil

  def get(ticker) do
    Repo.one(from(c in Currency, where: c.ticker == ^normalize(ticker)))
  end

  def register!(tickers) when is_list(tickers) do
    Enum.each(tickers, &register!/1)
  end

  def register!(ticker) do
    Repo.insert!(%Currency{ticker: normalize(ticker)}, on_conflict: :nothing)
  end

  def normalize(nil), do: nil

  def normalize(ticker) when is_binary(ticker) do
    ticker
  end

  def normalize(ticker) when is_atom(ticker) do
    Atom.to_string(ticker) |> String.upcase()
  end
end
