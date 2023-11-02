defmodule BoomWeb.BoompeekSocket do
  use Phoenix.Socket

  channel "room:*", BoomWeb.BoompeekChannel

  def connect(params, socket, _connect_info) do
    {:ok, assign(socket, :user_id, params["user_id"])}
  end

  def id(socket), do: "boompeek_socket:#{socket.assigns.user_id}"
end
