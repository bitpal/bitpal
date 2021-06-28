defmodule BitPalApi.ChannelHelpers do
  import Phoenix.View
  alias BitPalApi.ErrorView

  def render_error(changeset = %Ecto.Changeset{}) do
    {:error, render(ErrorView, "error.json", changeset: changeset)}
  end

  def render_error(error) when is_atom(error) do
    {:error, render(ErrorView, "error.json", error: error)}
  end
end
