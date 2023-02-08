defmodule BoomWeb.GameLive do
  use BoomWeb, :live_view

  def presence(game_id), do: "game/#{game_id}"

  def render(assigns) do
    ~H"""
    Current user: <%= @current_user %>

    <br/>
    game state: <pre> <%= inspect(@game, pretty: true) %> </pre>
    <div class="w-10/12 grid justify-center m-auto">
    <div class="grid grid-cols-10 grid-rows-10 gap-4 ">
    <%= for row <- 10..1 do %>
      <%= for col <- 1..10 do %>
        <div
        class="border-2 border-sky-500 w-16 h-16 justify-center items-center flex"
        phx-click="click"
        phx-value-cell={"#{col},#{row}"}>
          <%= col %> <%= row %>
        </div>
      <% end %>
    <% end %>
    </div>
    </div>
    """
  end

  def mount(%{"game_id" => game_id}, _session, socket) do
    current_user =
      if connected?(socket) do
        current_user = :rand.uniform(1000)

        # {:ok, _} =
        #   Boom.Presence.track(self(), presence(game_id), current_user, %{
        #     user: current_user
        #   })

        # Phoenix.PubSub.subscribe(Boom.PubSub, presence(game_id))
        Boom.GameServer.join_and_subscribe_me!(game_id, current_user)
        current_user
      else
        nil
      end

    socket =
      socket
      |> assign(game_id: game_id, current_user: current_user)
      |> assign_game()

    {:ok, socket}
  end

  def assign_game(socket) do
    case Boom.GameServer.get_game(socket.assigns.game_id) do
      {:ok, game} ->
        assign(socket, game: game)

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

  def handle_event("click", %{"cell" => cell_coordinates}, socket) do
    [col, row] =
      cell_coordinates
      |> String.split(",")
      |> Enum.map(fn x ->
        {x, _} = Integer.parse(x)
        x
      end)

    IO.inspect(col)
    IO.inspect(row)
    {:noreply, socket}
  end

  def handle_event(event, payload, socket) do
    IO.inspect(event)
    IO.inspect(payload)
    {:noreply, socket}
  end
end
