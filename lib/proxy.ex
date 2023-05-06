defmodule BitPal.Proxy do
  @moduledoc """
  Main entry point that routes requests to BitPalApi and BitPalWeb.

  It's main purpose is for code organization, but can be extended
  to server the api or documentation from a subdomain or similar.
  """

  use MainProxy.Proxy

  @impl MainProxy.Proxy
  def backends do
    [
      %{
        path: ~r{^/api},
        phoenix_endpoint: BitPalApi.Endpoint
        # If we want the api to be served from a subdomain:
        # host: ~r{^api\.*.*$},
        # Although that would require updating all routes in the api as well
        # (to remove the opening /api).
      },
      %{
        host: ~r{^.*$},
        phoenix_endpoint: BitPalWeb.Endpoint
      }
    ]
  end
end
