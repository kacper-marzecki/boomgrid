defmodule BoomWeb.GamesLive do
  use BoomWeb, :live_view
  alias BoomWeb.Components.Rpgui

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="rpgui-content framed w-1/2 text-left ">
      <ul>
        <li :for={game <- @games}>
          <%= game %> | <button phx-click="go_to_game" phx-value-game_id={game}>go to</button>
          | <button class="text-red-600" phx-click="kill_game" phx-value-game_id={game}>kill</button>
        </li>
      </ul>
      <h3>START NEW GAME:</h3>
      <div class="flex flex-row gap-3">
        <Rpgui.text_button
          text="Boomgrid gierka eksperyment"
          phx-click={JS.push("new_game", value: %{game: :boom})}
        />
        <Rpgui.text_button text="Ankh-Morpork" phx-click={JS.push("new_game", value: %{game: :ankh})} />
        <Rpgui.text_button text="Amazonki" phx-click={JS.push("new_game", value: %{game: :amazonki})} />
        <Rpgui.text_button
          text="mapa eksperyment"
          phx-click={JS.push("new_game", value: %{game: :mapa})}
        />
      </div>
    </div>
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
    socket =
      case game_type do
        "ankh" ->
          {:ok, game_id} = Boom.GameServer.start_new_game("ankh", Boom.Ankh.new_game())
          goto_ankh_morpork(socket, game_id)

        "amazonki" ->
          {:ok, game_id} = Boom.GameServer.start_new_game("amazonki", Boom.Amazonki.new_game())
          goto_amazonki(socket, game_id)

        "boom" ->
          {:ok, game_id} = Boom.LegacyGameServer.start_new_game()
          goto_boomgrid(socket, game_id)

        "mapa" ->
          redirect(
            socket,
            to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.BoardLive)
          )
      end

    {:noreply, socket}
  end

  def handle_event("go_to_game", %{"game_id" => game_id}, socket) do
    socket =
      cond do
        String.contains?(game_id, "ankh") ->
          goto_ankh_morpork(socket, game_id)

        String.contains?(game_id, "amazonki") ->
          goto_amazonki(socket, game_id)

        String.contains?(game_id, "boomgrid") ->
          goto_boomgrid(socket, game_id)
      end

    {:noreply, socket}
  end

  def goto_ankh_morpork(socket, game_id) do
    redirect(
      socket,
      to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.AnkhLive, game_id)
    )
  end

  def goto_amazonki(socket, game_id) do
    redirect(
      socket,
      to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.AmazonkiLive, game_id)
    )
  end

  def goto_boomgrid(socket, game_id) do
    redirect(
      socket,
      to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.GameLive, game_id)
    )
  end

  def handle_info("refresh", socket) do
    {:noreply, socket |> assign_games}
  end

  def assign_games(socket) do
    assign(socket,
      games: Boom.LegacyGameServer.active_game_ids()
    )
  end
end
