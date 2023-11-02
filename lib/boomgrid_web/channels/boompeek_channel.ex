defmodule BoomWeb.BoompeekChannel do
  use Phoenix.Channel

  def join("room:" <> _room_id, %{"username" => username}, socket) do
    {:ok, socket |> assign(username: username)}
  end

  def handle_info(:after_join, socket) do
    broadcast!(socket, "player_joined", %{"username" => socket.assigns.username})
    {:noreply, socket}
  end

  def handle_in("jump", msg, socket) do
    broadcast!(socket, "jump", msg |> Map.put("username", socket.assigns.username))
    {:noreply, socket}
  end
end
