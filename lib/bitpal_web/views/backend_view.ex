defmodule BitPalWeb.BackendView do
  use BitPalWeb, :view
  alias BitPal.Backend.Flowee.Connection.Binary
  require Logger

  def collect_rows(info_to_display, %{plugin: plugin, status: status, info: info}) do
    [
      {"Status", format_status(%{status: status})},
      {"Plugin", plugin}
      | collect_info_rows(info_to_display, info)
    ]
  end

  def collect_info_rows(_to_display, nil) do
    []
  end

  def collect_info_rows(to_display, info) do
    # Check if we're missing anything
    # to_display_set =
    #   Enum.reduce(to_display, MapSet.new(), fn {key, _}, acc ->
    #     MapSet.put(acc, key)
    #   end)
    #
    # for {key, _} <- info do
    #   if !MapSet.member?(to_display_set, key) do
    #     Logger.warn("Missing info key to display: #{key}")
    #   end
    # end

    Enum.flat_map(to_display, fn
      {key, translation} ->
        case Map.get(info, key) do
          nil ->
            []

          val ->
            [{translation, format(val)}]
        end
    end)
  end

  def format(val = %Binary{}) do
    Binary.to_hex(val)
  end

  def format(val) do
    val
  end

  def format_status(assigns) do
    ~H"""
      <span class="status">
        <%= case @status do %>
          <% :initializing -> %>
            <span class="initializing">
              Initializing
            </span>
          <% {:recovering, current, target} -> %>
            <span class="recovering">
              Recovering <%= current %> / <%= target %>
            </span>
          <% {:syncing, progress} -> %>
            <span class="syncing">
              Syncing <%= Float.round(progress * 100, 1) %>%
            </span>
          <% :ready -> %>
            <span class="ready">
              Ready
            </span>
          <% :stopped -> %>
            <span class="stopped">
              Stopped
            </span>
          <% {:error, :econnrefused} -> %>
            <span class="error">
              Connection refused
            </span>
          <% {:error, error} -> %>
            <span class="error">
              Unknown error <%= inspect(error) %>
            </span>
          <% :not_found -> %>
            <span class="not-found">
              Not found
            </span>
        <% end %>
      </span>
    """
  end
end
