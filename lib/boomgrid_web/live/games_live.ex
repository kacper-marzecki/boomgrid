defmodule BoomWeb.GamesLive do
  use BoomWeb, :live_view

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={game <- @games}>
        <%= game %> | <button phx-click="go_to_game" phx-value-game_id={game}>go to</button>
        | <button class="text-red-600" phx-click="kill_game" phx-value-game_id={game}>kill</button>
      </li>
    </ul>
    <button phx-click={JS.push("new_game", value: %{game: :boom})}>WIP Boomgrid</button>
    <button phx-click={JS.push("new_game", value: %{game: :ankh})}>Ankh-Morpork</button>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket |> assign_games}
  end

  def handle_event("kill_game", %{"game_id" => game_id}, socket) do
    Boom.LegacyGameServer.stop_game(game_id)
    Process.send_after(self(), "refresh", 1000)
    {:noreply, socket}
  end

  def handle_event("new_game", %{"game" => game_type}, socket) do
    {:ok, game_id} =
      case game_type do
        "ankh" -> Boom.GameServer.start_new_game("ankh", Boom.Ankh.new_game())
        "boom" -> Boom.LegacyGameServer.start_new_game()
      end

    {:noreply, socket |> redirect_to_game(game_id)}
  end

  def handle_event("go_to_game", %{"game_id" => game_id}, socket) do
    {:noreply, socket |> redirect_to_game(game_id)}
  end

  def handle_info("refresh", socket) do
    {:noreply, socket |> assign_games}
  end

  def redirect_to_game(socket, game_id) do
    IO.inspect(game_id, label: "################3")

    cond do
      String.contains?(game_id, "ankh") ->
        redirect(
          socket,
          to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.AnkhLive, game_id)
        )

      true ->
        redirect(
          socket,
          to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.GameLive, game_id)
        )
    end
  end

  def assign_games(socket) do
    assign(socket,
      games: Boom.LegacyGameServer.active_game_ids()
    )
  end
end
