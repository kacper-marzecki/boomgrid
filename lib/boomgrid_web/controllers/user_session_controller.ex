defmodule BoomWeb.UserSessionController do
  use BoomWeb, :controller
  require Logger

  alias BoomWeb.UserAuth

  def sign_in_page(conn, _params) do
    authorization_uri = OpenIDConnect.authorization_uri(:keycloak)
    render(conn, "new.html", error_message: nil, authorization_uri: authorization_uri)
  end

  def authorization_uri(conn, _params) do
    json(conn, %{uri: OpenIDConnect.authorization_uri(:keycloak)})
  end

  # The `Authentication` module here is an imaginary interface for setting session state
  def create(conn, params) do
    code = params["code"]

    with {:ok, tokens} <- OpenIDConnect.fetch_tokens(:keycloak, code),
         {:ok, claims} <- OpenIDConnect.verify(:keycloak, tokens["id_token"]) do
      username = claims["preferred_username"]
      Logger.info("claims: #{inspect(claims)}")

      conn
      |> Plug.Conn.put_session(:current_user, username)
      |> Plug.Conn.put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(code)}")
      |> redirect(to: "/")
    else
      _ ->
        conn
        |> put_flash(:error, "Unrecognized user.")
        |> redirect(to: "/")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
