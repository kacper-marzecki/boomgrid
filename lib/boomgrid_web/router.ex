defmodule BoomWeb.Router do
  use BoomWeb, :router
  import BoomWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {BoomWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user

    if Mix.env() == :dev do
      plug :set_mock_user
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BoomWeb do
    pipe_through :browser
    get("/session", UserSessionController, :create)
    get("/session/delete", UserSessionController, :delete)
    get("/session/authorization-uri", UserSessionController, :authorization_uri)
  end

  scope "/", BoomWeb do
    pipe_through([:browser, :require_authenticated_user])
    import Phoenix.LiveDashboard.Router
    live_dashboard "/dashboard", metrics: BoomWeb.Telemetry
    get("/", PageController, :index)
    live "/board", BoardLive
    live "/ankh/:game_id", AnkhLive
    live "/amazonki/:game_id", AmazonkiLive
    live "/sprites", SpritesLive
    live "/games", GamesLive
    live "/game/:game_id", GameLive
  end

  if Mix.env() == :dev do
    def set_mock_user(conn, _opts) do
      mock_user = "mock#{Boom.Id.gen_id()}"
      user = Plug.Conn.get_session(conn, :current_user) || mock_user

      conn
      |> Plug.Conn.assign(:current_user, user)
      |> Plug.Conn.put_session(:current_user, user)
    end
  end
end
