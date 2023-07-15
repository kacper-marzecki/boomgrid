defmodule Boomgrid.UserSession.MockUser do
  use BoomWeb, :live_view

  def render(assigns) do
    ~H"""
    <form for={:user_form} phx-submit="set_user">
      <input type="text" name="user" value={@user} />
      <button type="submit">set</button>
    </form>
    """
  end

  def handle_event("set_user", %{"user" => user}, socket) do
    IO.inspect(user)
    {:noreply, socket |> Phoenix.LiveView.push_patch(to: "/?mock_user=#{user}")}
  end

  def mount(_, %{"current_user" => username} = session, socket) do
    user = String.to_atom(username)
    {:ok, socket |> assign(:user, user)}
  end
end
