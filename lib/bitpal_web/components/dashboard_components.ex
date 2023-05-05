defmodule BitPalWeb.DashboardComponents do
  use BitPalWeb, :component

  def control_buttons(currency_id, %{status: _status, is_enabled: is_enabled}) do
    if is_enabled do
      disable_button(%{currency_id: currency_id})
    else
      enable_button(%{currency_id: currency_id})
    end

    # end
  end

  def can_start(:stopped), do: true
  def can_start({:stopped, :nomal}), do: true
  def can_start({:stopped, :shutdown}), do: true
  def can_start({:stopped, {:shutdown, _}}), do: false
  def can_start({:stopped, {:error, _}}), do: false
  def can_start(:unknown), do: true
  def can_start(_), do: false

  def enable_button(assigns) do
    ~H"""
    <button phx-click="enable" phx-value-id={@currency_id}>
      Enable
    </button>
    """
  end

  def disable_button(assigns) do
    ~H"""
    <button phx-click="disable" phx-value-id={@currency_id}>
      Disable
    </button>
    """
  end

  def start_button(assigns) do
    ~H"""
    <button phx-click="start" phx-value-id={@currency_id}>
      Start
    </button>
    """
  end

  def stop_button(assigns) do
    ~H"""
    <button phx-click="stop" phx-value-id={@currency_id}>
      Stop
    </button>
    """
  end
end
