defmodule BitPal.ExchangeRate.Sources.Kraken do
  @moduledoc """
  Source exchange rate data from Kraken

  https://docs.kraken.com/rest/
  """

  @behaviour BitPal.ExchangeRate.Source

  alias BitPal.Currencies

  @id_translation %{
    BTC: :XBT
  }
  @rev_id_translation Enum.reduce(@id_translation, %{}, fn {id, name}, acc ->
                        Map.put(acc, Atom.to_string(name), Atom.to_string(id))
                      end)

  @asset_pairs_url "https://api.kraken.com/0/public/AssetPairs"
  @ticker_url "https://api.kraken.com/0/public/Ticker?pair="

  @impl true
  def name, do: "Kraken"

  @impl true
  def rate_limit_settings do
    %{
      timeframe: 45,
      timeframe_unit: :seconds,
      timeframe_max_requests: 15
    }
  end

  @impl true
  def supported do
    {:ok, body} = BitPalSettings.http_client().request_body(@asset_pairs_url)

    body
    |> Poison.decode!()
    |> Map.fetch!("result")
    |> Enum.reduce(%{}, fn {_, info}, acc ->
      with {:ok, {base, xquote}} <- into_pair(info),
           true <- Currencies.is_crypto(base) do
        list = Map.get(acc, base, [])
        Map.put(acc, base, [xquote | list])
      else
        _ -> acc
      end
    end)
    |> Enum.reduce(%{}, fn {crypto_id, fiat}, acc ->
      Map.put(acc, crypto_id, Enum.into(fiat, MapSet.new()))
    end)
  end

  defp into_pair(%{"wsname" => names}) do
    with [base, xquote] <- String.split(names, "/"),
         {:ok, base} <- base |> rev_transform_id() |> Currencies.cast(),
         {:ok, xquote} <- xquote |> rev_transform_id() |> Currencies.cast() do
      {:ok, {base, xquote}}
    else
      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  @impl true
  def request_type, do: :pair

  @impl true
  def rates(opts) do
    pair = {base, xquote} = Keyword.fetch!(opts, :pair)
    pair_s = pair2str(pair)

    {:ok, body} = BitPalSettings.http_client().request_body(@ticker_url <> pair_s)

    {:ok, rate} =
      body
      |> Poison.decode!()
      |> Map.fetch!("result")
      |> Map.values()
      |> List.first()
      |> Map.fetch!("c")
      |> List.first()
      |> Decimal.cast()

    %{base => %{xquote => rate}}
  end

  defp pair2str({base, xquote}) do
    Atom.to_string(transform_id(base)) <> Atom.to_string(transform_id(xquote))
  end

  defp transform_id(base) do
    Map.get(@id_translation, base, base)
  end

  defp rev_transform_id(base) do
    Map.get(@rev_id_translation, base, base)
  end
end
