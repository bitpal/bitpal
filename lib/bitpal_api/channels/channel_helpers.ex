defmodule BitPalApi.ChannelHelpers do
  alias BitPalApi.ErrorView

  def render_error(error) when is_struct(error) do
    {:error, ErrorView.render_error(error)}
  end
end
