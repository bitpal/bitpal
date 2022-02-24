defmodule BitPalWeb.DashboardView do
  use BitPalWeb, :view
  import BitPalWeb.BackendView, only: [format_status: 1]

  def control_buttons(currency_id, status) do
    if can_start(status) do
      start_button(%{currency_id: currency_id})
    else
      stop_button(%{currency_id: currency_id})
    end
  end

  def can_start(:stopped), do: true
  def can_start({:stopped, :nomal}), do: true
  def can_start({:stopped, :shutdown}), do: true
  def can_start({:stopped, {:shutdown, _}}), do: false
  def can_start({:stopped, {:error, _}}), do: false
  def can_start(:unknown), do: true
  def can_start(_), do: false

  # def can_stop(:stopped), do: false
  # def can_stop({:stopped, :nomal}), do: false
  # def can_stop({:stopped, :shutdown}), do: false
  # def can_stop({:stopped, {:shutdown, _}}), do: true
  # def can_stop({:stopped, {:error, _}}), do: true
  # def can_start(:unknown), do: false

  # def can_stop(:starting), do: true
  # def can_stop({:recovering, _, _}), do: true
  # def can_stop({:syncing, _}), do: true
  # def can_stop(_), do: false

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
