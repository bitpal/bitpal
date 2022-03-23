defmodule BitPalWeb.ExchangeRateLive do
  use BitPalWeb, :live_view
  alias BitPal.ExchangeRateEvents
  alias BitPal.ExchangeRates
  alias BitPal.ExchangeRateSupervisor

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ExchangeRateEvents.subscribe_raw()
    end

    sources =
      ExchangeRateSupervisor.sources()
      |> Enum.sort(fn a, b -> a.prio > b.prio end)

    column_sort =
      sources
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {%{source: source}, index}, acc ->
        Map.put(acc, source, index)
      end)

    source_headers =
      sources
      |> Enum.map(fn %{name: name} -> name end)

    source_order =
      column_sort
      |> Enum.sort(fn {_, ai}, {_, bi} -> ai < bi end)
      |> Enum.map(fn {source, _} -> source end)

    # A multi level nesting of
    #
    #   %{base => %{quote => [rate]}}
    #
    # where rates are sorted in `source_order`, and contains `value: nil` if the
    # rate corresponding rate doesn't exist.
    all_rates =
      ExchangeRates.all_raw_exchange_rates()
      # First level is by base
      |> Enum.group_by(
        fn %{rate: %{pair: {base, _}}} -> base end,
        fn v -> v end
      )
      |> Enum.map(fn {base, rates_by_base} ->
        # Second is by quote
        rates_by_base =
          rates_by_base
          |> Enum.group_by(
            fn %{rate: %{pair: {_, xquote}}} -> xquote end,
            fn v -> v end
          )
          |> Enum.map(fn {xquote, rates_by_quote} ->
            {xquote, transform_and_sort(rates_by_quote, source_order)}
          end)
          |> Enum.into(%{})

        {base, rates_by_base}
      end)
      |> Enum.into(%{})

    {:ok,
     assign(socket,
       source_headers: source_headers,
       source_order: source_order,
       all_rates: all_rates,
       breadcrumbs: Breadcrumbs.exchange_rates(socket)
     )}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.ExchangeRateView, "show.html", assigns)
  end

  @impl true
  def handle_info({{:exchange_rate, :raw_update}, pair}, socket) do
    {:noreply, update_pair(pair, socket)}
  end

  defp update_pair(pair = {base, xquote}, socket) do
    case ExchangeRates.fetch_raw_exchange_rates(pair) do
      {:ok, new_rates} ->
        all_rates = socket.assigns.all_rates
        source_order = socket.assigns.source_order

        # Safeguard against new base/quote ids are introduced.
        # But note that we do not support new sources dynamically.
        rates_by_base = Map.get(all_rates, base, %{})

        rates_by_quote =
          new_rates
          |> transform_and_sort(source_order)

        rates_by_base = Map.put(rates_by_base, xquote, rates_by_quote)

        assign(socket,
          all_rates: Map.put(all_rates, base, rates_by_base)
        )

      :error ->
        socket
    end
  end

  defp transform_and_sort(rates, source_order) do
    # Sort by soource, insert nil if a source isn't represented
    rates_by_source =
      Enum.reduce(rates, %{}, fn rate, acc ->
        Map.put(acc, rate.source, %{
          source: rate.source,
          value: rate.rate.rate,
          updated: rate.updated
        })
      end)

    Enum.map(source_order, fn source ->
      Map.get(rates_by_source, source, %{source: source, value: nil})
    end)
  end
end
