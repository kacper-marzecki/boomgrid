defmodule BoomWeb.GameLive do
  use BoomWeb, :live_view

  def presence(game_id), do: "game/#{game_id}"

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2" phx-window-keyup="key_press">
      <div>
        Current user: <%= @current_user %>
        <br/>
        <div style="overflow-y: scroll; height: 50em;"> game state: 
          <pre> <%= inspect(@game, pretty: true) %> </pre>
        </div>
        <button phx-click="next_round">Next round</button>
      </div>
    <div class="w-10/12 grid justify-center m-auto">
    <div class="grid grid-cols-10 grid-rows-10 gap-4 ">
    <%= for row <- 10..1 do %>
      <%= for col <- 1..10 do %>
        <div
          class={"border-2 border-sky-500 w-16 h-16 justify-center items-center flex #{field_class(@game, col, row, @player_id)}"}
        phx-click="click"
        phx-value-cell={"#{col},#{row}"}>
          <%= col %> <%= row %>
        <span :if={Boom.Game.wall?(@game, col, row)}>BLOCK</span>
        </div>
      <% end %>
    <% end %>
    </div>
    </div>
    </div>
    """
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
      |> assign(game_id: game_id, current_user: current_user, player_id: player_id)
      |> assign_game()

    {:ok, socket}
  end

  def field_class(game, col, row, player_id) do
    cond do
      Boom.Game.wall?(game, col, row) -> "bg-slate-700"
      true -> ""
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

        {:noreply, put_flash(socket, :info, "Next round")}

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

    {:noreply, socket}
  end

  def handle_event(event, payload, socket) do
    IO.inspect(event)
    IO.inspect(payload)
    {:noreply, socket}
  end
end
