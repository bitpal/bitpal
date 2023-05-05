defmodule BitPalApi.ChannelHelpers do
  alias BitPalApi.ErrorJSON

  def render_error(error) when is_struct(error) do
    {:error, ErrorJSON.render_error(error)}
  end
end
