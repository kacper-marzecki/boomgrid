defmodule BoomWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      BoomWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    sid = get_session(conn, :sid)

    conn
    |> renew_session()
    |> redirect(
      external:
        "https://keycloak.fubar.online/auth/realms/boomgrid/protocol/openid-connect/logout?client_id=#{sid}&post_logout_redirect_uri=https://boomgrid.fubar.online"
    )
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    assign(conn, :current_user, get_session(conn, :current_user))
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> redirect(external: OpenIDConnect.authorization_uri(:keycloak))
      |> halt()
    end
  end

  defp signed_in_path(_conn), do: "/"
end
