defmodule BitPal.ExchangeRate.Sources.Kraken do
  @moduledoc """
  Source exchange rate data from Kraken

  https://docs.kraken.com/rest/
  """

  @behaviour BitPal.ExchangeRate.Source

  alias BitPal.Currencies

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
      with {:ok, {from, to}} <- into_pair(info),
           true <- Currencies.is_crypto(from) do
        list = Map.get(acc, from, [])
        Map.put(acc, from, [to | list])
      else
        _ -> acc
      end
    end)
    |> Enum.reduce(%{}, fn {crypto_id, fiat}, acc ->
      Map.put(acc, crypto_id, Enum.into(fiat, MapSet.new()))
    end)
  end

  defp into_pair(%{"wsname" => names}) do
    with [from, to] <- String.split(names, "/"),
         {:ok, from} <- Currencies.cast(from),
         {:ok, to} <- Currencies.cast(to) do
      {:ok, {from, to}}
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
    pair = {from, to} = Keyword.fetch!(opts, :pair)
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

    %{from => %{to => rate}}
  end

  defp pair2str({from, to}) do
    Atom.to_string(from) <> Atom.to_string(to)
  end
end
