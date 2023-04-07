defmodule BoomWeb.GameLive do
  use BoomWeb, :live_view

  @classes [
    "grid-cols-1",
    "grid-rows-1",
    "grid-cols-2",
    "grid-rows-2",
    "grid-cols-3",
    "grid-rows-3",
    "grid-cols-4",
    "grid-rows-4",
    "grid-cols-5",
    "grid-rows-5",
    "grid-cols-6",
    "grid-rows-6",
    "grid-cols-7",
    "grid-rows-7",
    "grid-cols-8",
    "grid-rows-8",
    "grid-cols-9",
    "grid-rows-9",
    "grid-cols-10",
    "grid-rows-10"
  ]

  def presence(game_id), do: "game/#{game_id}"

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2" phx-window-keyup="key_press">
      <div>
        Current user: <%= @current_user %>
        <br /> PlayerId: <%= @player_id %>
        <br />
        <div style="overflow-y: scroll; height: 50em;">
          game state: <pre> <%= inspect(@game, pretty: true) %> </pre>
        </div>
        <button phx-click="next_round">Next round</button>
      </div>
      <div class="w-10/12 grid justify-center m-auto">
        <div class={"grid grid-cols-#{@game_size} grid-rows-#{@game_size} "}>
          <%= for row <- @game_size..1 do %>
            <%= for col <- 1..@game_size do %>
              <div
                class={"w-16 h-16 justify-center justify-items-stretch items-stretch flex cursor-pointer #{field_class(@game, col, row, @player_id)}"}
                phx-click="click"
                phx-value-cell={"#{col},#{row}"}
              >
                <div><%= col %> <%= row %></div>
                <div><span :if={@click == [col, row]}>CLICK</span></div>
                <span :if={Boom.Game.wall?(@game, col, row)}>BLOCK</span>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def render_field(game, col, row, player_id) do
    cond do
      Boom.Game.wall?(game, col, row) -> "bg-slate-700"
      Boom.Game.player_position?(game, player_id, col, row) -> "player_tile_#{player_id}"
      true -> "floor_tile"
    end
  end

  # pole może być :
  # - puste
  # zajęte przez ściane 
  #
  def render_tile(game, col, row, observing_player) do
    cond do
      Boom.Game.wall?(game, col, row) ->
        "bg-slate-700"

      Boom.Game.player_position?(game, observing_player, col, row) ->
        "player_tile_#{observing_player}"

      true ->
        "floor_tile"
    end
  end

  def mount(%{"game_id" => game_id}, _session, socket) do
    {current_user, player_id} =
      if connected?(socket) do
        current_user = :rand.uniform(1000)
        # Phoenix.PubSub.subscribe(Boom.PubSub, presence(game_id))
        {:ok, player_id} = Boom.GameServer.join_and_subscribe_me!(game_id, current_user)

        {current_user, player_id}
      else
        {nil, nil}
      end

    socket =
      socket
      |> assign(click: nil)
      |> assign(game_size: 6)
      |> assign(game_id: game_id, current_user: current_user, player_id: player_id)
      |> assign_game()

    {:ok, socket}
  end

  def field_class(game, col, row, player_id) do
    cond do
      Boom.Game.wall?(game, col, row) -> "bg-slate-700"
      Boom.Game.player_position?(game, player_id, col, row) -> "player_tile_#{player_id}"
      true -> "floor_tile"
    end
  end

  def assign_game(socket) do
    case Boom.GameServer.get_game(socket.assigns.game_id) do
      {:ok, game_server_state} ->
        assign(socket, game: game_server_state.game)

      {:error, e} ->
        socket
        |> Phoenix.LiveView.put_flash(:info, "Cannot find the game")
        |> push_redirect(to: BoomWeb.Router.Helpers.live_path(socket, BoomWeb.GamesLive))
    end
  end

  def handle_info({:new_game_state, state}, socket) do
    {:noreply,
     assign(
       socket,
       game: state
     )}
  end

  def handle_event("key_press", %{"key" => key}, socket) do
    case key do
      " " ->
        Boom.GameServer.command(socket.assigns.game_id, socket.assigns.player_id, %{
          cmd: :next_round
        })

        {:noreply, put_flash(socket, :info, "Next round") |> assign(click: nil)}

      _ ->
        {:noreply, socket}
    end

    {:noreply, socket}
  end

  def handle_event("next_round", _payload, socket) do
    Boom.GameServer.command(socket.assigns.game_id, socket.assigns.current_user, %{
      cmd: :next_round
    })

    {:noreply, socket}
  end

  def handle_event("click", %{"cell" => cell_coordinates}, socket) do
    [col, row] =
      cell_coordinates
      |> String.split(",")
      |> Enum.map(fn x ->
        {x, _} = Integer.parse(x)
        x
      end)

    Boom.GameServer.command(socket.assigns.game_id, socket.assigns.player_id, %{
      cmd: :move,
      to: [col, row]
    })

    {:noreply, socket |> assign(click: [col, row])}
  end

  def handle_event(event, payload, socket) do
    IO.inspect(event)
    IO.inspect(payload)
    {:noreply, socket}
  end
end
