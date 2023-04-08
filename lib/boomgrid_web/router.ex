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
      plug :set_random_user
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BoomWeb do
    pipe_through :browser
    get("/", PageController, :index)
    get("/session", UserSessionController, :create)
    get("/session/delete", UserSessionController, :delete)
    get("/session/authorization-uri", UserSessionController, :authorization_uri)
  end

  scope "/", BoomWeb do
    pipe_through([:browser, :require_authenticated_user])
    import Phoenix.LiveDashboard.Router
    live_dashboard "/dashboard", metrics: BoomWeb.Telemetry
    live "/board", BoardLive
    live "/games", GamesLive
    live "/game/:game_id", GameLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", BoomWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).

  def set_random_user(conn, opts) do
    Plug.Conn.assign(conn, :current_user, UUID.uuid4())
  end
end
