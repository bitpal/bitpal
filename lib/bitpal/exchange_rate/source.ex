defmodule BitPal.ExchangeRate.Source do
  alias BitPalSchemas.Currency

  @type rate_limit_settings :: %{
          timeframe: non_neg_integer,
          timeframe_unit: :hours | :minutes | :seconds | :milliseconds,
          timeframe_max_requests: non_neg_integer
        }

  @callback name() :: String.t()

  @callback rate_limit_settings() :: rate_limit_settings()

  @callback supported() :: %{Currency.id() => MapSet.t(Currency.id())}

  # - :pair means that there's a separate request for each supported pair.
  # - :from means that we only need to specify the cryptocurrency, and we'll get
  #         all supported pairs in a single response.
  # - :multi means we can supply multiple to/from as lists.
  @callback request_type() :: :pair | :from | :multi

  @callback rates(keyword) :: %{Currency.id() => %{Currency.id() => Decimal.t()}}

  # defp supported?(map, {from, to}) do
  #   if list = Map.get(map, from, nil) do
  #     Enum.member?(list, to)
  #   else
  #     false
  #   end
  # end
end
