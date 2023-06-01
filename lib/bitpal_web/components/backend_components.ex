defmodule BitPalWeb.BackendComponents do
  use BitPalWeb, :component

  alias BitPal.Backend.Flowee.Connection.Binary
  require Logger

  def info_to_display(:BCH) do
    [
      {:version, "Version"},
      {:blocks, "Processed blocks"},
      {:difficulty, "Difficulty"},
      {:verification_progress, "Verification progress"},
      {:chain, "Chain"},
      {:best_block_hash, "Chain tip block hash"}
    ]
  end

  def info_to_display(:XMR) do
    [
      {"version", "Version"},
      {"update_available", "Update available?"},
      {"height", "Processed blocks"},
      {"difficulty", "Difficulty"},
      {"nettype", "Chain"},
      {"top_block_hash", "Chain tip block hash"}
    ]
  end

  def collect_rows(%{plugin: plugin, status: status, info: info, currency_id: currency_id}) do
    [
      {"Status", format_backend_status(%{status: status})},
      {"Plugin", plugin}
      | collect_info_rows(info_to_display(currency_id), info)
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

  defp format(val = %Binary{}) do
    Binary.to_hex(val)
  end

  defp format(val) do
    val
  end

  def format_backend_status(assigns) do
    ~H"""
    <span class="status">
      <%= case @status do %>
        <% :starting -> %>
          <span class="starting">
            Starting
          </span>
        <% {:recovering, {current, target}} -> %>
          <span class="recovering">
            Recovering <%= current %>/<%= target %>
          </span>
        <% {:syncing, {current, target}} -> %>
          <span class="syncing">
            Syncing <%= current %>/<%= target %> (<%= Float.round(current / target * 100, 1) %>%)
          </span>
        <% {:syncing, progress} -> %>
          <span class="syncing">
            Syncing <%= Float.round(progress * 100, 1) %>%
          </span>
        <% :ready -> %>
          <span class="ready">
            Ready
          </span>
        <% {:stopped, :shutdown} -> %>
          <span class="stopped">
            Stopped
          </span>
        <% {:stopped, {:shutdown, :econnrefused}} -> %>
          <span class="error">
            Connection refused
          </span>
        <% {:stopped, {:shutdown, reason}} -> %>
          <span class="stopped">
            Stopped <%= inspect(reason) %>
          </span>
        <% {:stopped, {:error, :econnrefused}} -> %>
          <span class="error">
            Connection refused
          </span>
        <% {:stopped, {:error, error}} -> %>
          <span class="error">
            Unknown error <%= inspect(error) %>
          </span>
        <% :plugin_not_found -> %>
          <span class="not-found">
            Plugin not found
          </span>
        <% :unknown -> %>
          <span class="unknown">
            Unknown error
          </span>
        <% status -> %>
          <span class="unknown">
            <%= inspect(status) %>
          </span>
      <% end %>
    </span>
    """
  end
end
