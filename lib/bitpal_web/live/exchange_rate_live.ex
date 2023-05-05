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
      ExchangeRates.all_unprioritized_exchange_rates()
      # First level is by base
      |> Enum.group_by(fn rate -> rate.base end)
      |> Map.new(fn {base, rates_by_base} ->
        # Second is by quote
        rates_by_base =
          rates_by_base
          |> Enum.group_by(fn rate -> rate.quote end)
          |> Map.new(fn {xquote, rates_by_quote} ->
            {xquote, sort(Enum.map(rates_by_quote, &transform/1), source_order)}
          end)

        {base, rates_by_base}
      end)

    {:ok,
     assign(socket,
       source_headers: source_headers,
       source_order: source_order,
       all_rates: all_rates,
       breadcrumbs: Breadcrumbs.exchange_rates(socket)
     )}
  end

  @impl true
  def handle_info({{:exchange_rate, :raw_update}, rates}, socket) do
    {:noreply, update_rates(rates, socket)}
  end

  defp update_rates(new_rates, socket) do
    all_rates = socket.assigns.all_rates
    source_order = socket.assigns.source_order

    new_rates =
      Map.new(new_rates, fn {base, quotes} ->
        {base,
         Map.new(quotes, fn {xquote, rate} ->
           {xquote, [transform(rate)]}
         end)}
      end)

    rates =
      Map.merge(all_rates, new_rates, fn _base, xs, ys ->
        Map.merge(xs, ys, fn _quote, existing, new ->
          (new ++ existing)
          |> Enum.uniq_by(fn rate -> rate.source end)
          |> sort(source_order)
        end)
      end)

    assign(socket, all_rates: rates)
  end

  defp transform(rate) do
    %{source: rate.source, updated: rate.updated_at, value: rate.rate}
  end

  defp sort(rates, source_order) do
    rates_by_source = Map.new(rates, fn rate -> {rate.source, rate} end)

    # Sort by source, insert nil if a source isn't represented
    Enum.map(source_order, fn source ->
      Map.get(rates_by_source, source, %{source: source, value: nil})
    end)
  end
end
