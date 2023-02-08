defmodule BoomWeb.PageController do
  use BoomWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
