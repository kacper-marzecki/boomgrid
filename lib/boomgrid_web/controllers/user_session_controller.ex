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
         {:ok, claims} <- OpenIDConnect.verify(:keycloak, tokens["id_token"]),
         :ok <- validate_session_hasnt_been_logged_out(claims["sid"]) do
      username = claims["preferred_username"]
      Logger.info("claims: #{inspect(claims)}")
      Logger.info("preferred_username: #{inspect(claims)}")

      conn
      |> Plug.Conn.put_session(:current_user, username)
      |> Plug.Conn.put_session(:sid, claims["sid"])
      |> Plug.Conn.put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(code)}")
      |> redirect(to: "/")
    else
      other ->
        IO.inspect(other, label: "OTHER AUTH RESPONSE")

        conn
        |> redirect(to: "/")
    end
  end

  def validate_session_hasnt_been_logged_out(_session_id) do
    # case Boom.Repo.get_by(Boom.UserSession.LoggedOutSession, session_id: session_id) do
    #   nil -> :ok
    #   _ -> :error
    # end
    # STUB
    # TODO - użyć logout_url z discovery_url keycloak do logout'u zamiast
    :ok
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
