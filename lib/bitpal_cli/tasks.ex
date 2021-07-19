defmodule BitPalCli.Tasks do
  alias BitPal.Authentication.Tokens
  alias BitPal.Repo
  alias BitPal.Stores

  def start do
    BitPal.Application.start_lean()
  end

  def show_stores do
    start()

    Stores.all()
    |> render_stores()
  end

  def show_store_tokens(store_id) do
    start()
    store = Stores.fetch!(store_id) |> Repo.preload([:access_tokens])

    store.access_tokens
    |> render_tokens()
  end

  def show_store_invoices(store_id) do
    start()
    store = Stores.fetch!(store_id) |> Repo.preload([:invoices])

    store.invoices
    |> Scribe.print(
      data: [
        {"amount", fn x -> crypto_to_string(x.amount) end},
        {"address", :address_id},
        {"status", :status}
      ]
    )
  end

  def create_store(label) do
    start()

    Stores.create!(label: label)
    |> render_stores()
  end

  def create_access_token(store_id) do
    start()

    Stores.fetch!(store_id)
    |> Tokens.create_token!()
    |> render_tokens()
  end

  def render_stores(stores) do
    stores
    |> Repo.preload([:invoices, :access_tokens], force: true)
    |> Scribe.print(
      data: [{"ID", :id}, {"label", :label}, {"invoice count", fn x -> length(x.invoices) end}]
    )
  end

  def render_tokens(tokens) do
    tokens
    |> Scribe.print(data: [{"ID", :id}, {"store", :store_id}, {"token data", :data}])
  end

  @spec crypto_to_string(Money.t()) :: String.t()
  def crypto_to_string(money) do
    Money.to_string(money,
      strip_insignificant_zeros: true,
      symbol_on_right: true,
      symbol_space: true
    )
  end
end
