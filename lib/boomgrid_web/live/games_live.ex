defmodule BoomWeb.GamesLive do
  use BoomWeb, :live_view

  def render(assigns) do
    ~H"""
    <ul>
     <li :for={game <-  @games}>
     <%= game %>
        | <button phx-click="go_to_game" phx-value-game_id={game}>go to</button>
        | <button class="text-red-600" phx-click="kill_game" phx-value-game_id={game} >kill</button></li>
    </ul>
    <button phx-click="new_game">New game</button>
    """
  end

  def mount(params, session, socket) do
    {:ok, socket |> assign_games}
  end

  def handle_event("kill_game", %{"game_id" => game_id}, socket) do
    Boom.GameServer.stop_game(game_id)
    Process.send_after(self(), "refresh", 1000)
    {:noreply, socket}
  end

  def handle_event("new_game", _, socket) do
    {:ok, game_id} = Boom.GameServer.start_new_game()

    {:noreply, socket |> redirect_to_game(game_id)}
  end

  def handle_event("go_to_game", %{"game_id" => game_id}, socket) do
    {:noreply, socket |> redirect_to_game(game_id)}
  end

  def handle_info("refresh", socket) do
    {:noreply, socket |> assign_games}
  end

  def redirect_to_game(socket, game_id) do
    push_redirect(
      socket,
      to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.GameLive, game_id)
    )
  end

  def assign_games(socket) do
    assign(socket, games: Boom.GameServer.active_game_ids())
  end
end
