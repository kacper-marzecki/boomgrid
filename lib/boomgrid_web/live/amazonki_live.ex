defmodule BoomWeb.AmazonkiLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS
  alias BoomWeb.Components.Rpgui

  alias Boom.GameServer
  alias Boom.Amazonki

  require Logger

  def debug_section(assigns) do
    ~H"""
    <div class="rpgui-content">
      <Rpgui.text_button phx-click={JS.push("toggle_console_open")} text="console" />
      <Rpgui.text_button phx-click={JS.push("toggle_game_state_open")} text="game_state" />
      <div
        id="log"
        style="position: fixed; left: 0; top: 0; background: rgba(76, 175, 80, 0.5); z-index: 998; "
        class={"h-[200px] w-full overflow-scroll #{!@console_open? && "hidden"}"}
      >
        <Rpgui.text_button class="float-right" phx-click={JS.push("toggle_console_open")} text="X" />

        <p :for={log <- @game.log}><%= log %></p>
      </div>
      <div
        style="position: fixed; left: 0; top: 0; background: rgba(76, 175, 80, 0.5); z-index: 998; "
        class={"h-[200px] w-full overflow-scroll #{!@game_state_open? && "hidden"}"}
      >
        <Rpgui.text_button class="float-right" phx-click={JS.push("toggle_game_state_open")} text="X" />

        <pre style="overflow: scroll; height: 200px;" class="selectable_text">
        <p>
          <%= inspect(assigns |> Map.drop([:__changed__]), pretty: true) %>
          </p>
        </pre>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <.debug_section {assigns} />
    <div class="rpgui-content" phx-window-keyup="key_clicked">
      <div class="flex flex-row h-screen  w-screen ">
        <div class="framed flex flex-col justify-center w-full h-full ">
          <%!-- UI  --%>
          <div class="flex h-full">
            <div class="framed-grey w-[30%]">
              <div class=" h-[30%]">
                <p :if={@game.round > 0}>Role: <%= @game.player_roles[@player] %></p>

                <p :if={@game.round > 0}>Round: <%= @game.round %></p>
                <table :if={@game.round > 0} class="table-auto w-full text-center text-white">
                  <thead>
                    <tr>
                      <th></th>
                      <th>empty</th>
                      <th>trap</th>
                      <th>gold</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td>Found</td>
                      <td><%= Amazonki.count_open_doors(@game, :empty) %></td>
                      <td><%= Amazonki.count_open_doors(@game, :trap) %></td>
                      <td><%= Amazonki.count_open_doors(@game, :gold) %></td>
                    </tr>
                    <tr>
                      <td>Hand</td>
                      <td><%= Amazonki.count_player_doors(@game, @player, :empty) %></td>
                      <td><%= Amazonki.count_player_doors(@game, @player, :trap) %></td>
                      <td><%= Amazonki.count_player_doors(@game, @player, :gold) %></td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div class="overflow-y-scroll h-[70%]">
                <p :for={log <- @game.log}><%= log %></p>
              </div>
            </div>
            <%!-- OPCJE --%>
            <div class="framed-grey w-[70%] h-full flex flex-row justify-around">
              <%= case {@game.winner, @game.round} do %>
                <% {nil, 0} -> %>
                  <Rpgui.text_button
                    :if={can_join(@game, @player)}
                    text="Dołącz"
                    phx-click="join_game"
                  />
                  <%= @game.players |> inspect %>
                  <%= length(@game.players) > 2 %>
                  <Rpgui.text_button
                    :if={length(@game.players) > 2}
                    text="start game"
                    phx-click="start_game"
                  />
                <% {nil, _} -> %>
                  <table class="table-auto w-full text-center text-white">
                    <thead>
                      <tr>
                        <th>Player</th>
                        <th>cards</th>
                        <th>key</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={player <- @game.players}
                        class={"cursor-rpg #{if @player == @game.key_holder, do: "hover:bg-sky-700"}"}
                        phx-click={
                          if @player == @game.key_holder,
                            do: JS.push("player_clicked", value: %{player: player})
                        }
                      >
                        <td><%= player %></td>
                        <td><%= @game.player_cards[player] |> length %></td>
                        <td><%= if @game.key_holder == player, do: "X", else: "" %></td>
                      </tr>
                    </tbody>
                  </table>
                <% {winner, _} -> %>
                  <%= "GAME WON BY: #{winner}" %>
              <% end %>
            </div>
          </div>

          <%!-- <div class="whitespace-nowrap overflow-x-scroll h-[20%]"></div> --%>
        </div>
      </div>
    </div>
    <script src="https://unpkg.com/panzoom@9.4.0/dist/panzoom.min.js" />
    """
  end

  def mount(%{"game_id" => game_id}, %{"current_user" => username} = _session, socket) do
    player = String.to_atom(username)

    if connected?(socket) do
      GameServer.subscribe_me!(game_id)
    end

    socket =
      with {:ok, game} <- GameServer.get_game(game_id) do
        socket
        |> assign(
          game: game,
          console_open?: false,
          game_state_open?: false,
          player: player,
          game_id: game_id,
          # BOARD assigns
          action: nil
        )
      else
        {:error, e} ->
          err = "Error while starting up Amazonki LiveView: #{inspect(e)}"
          Logger.error(err)

          socket
          |> Phoenix.LiveView.put_flash(:error, err)
          |> Phoenix.LiveView.redirect(to: "/games")
      end

    {:ok, socket}
  end

  def handle_event("join_game", _payload, socket) do
    if can_join(socket.assigns.game, socket.assigns.player) do
      GameServer.execute(socket.assigns.game_id, fn game ->
        Amazonki.add_player(game, socket.assigns.player)
      end)
    end

    {:noreply, socket}
  end

  def handle_event("start_game", _payload, socket) do
    IO.inspect(socket.assigns.game)

    if Amazonki.can_start_game?(socket.assigns.game) do
      GameServer.execute(socket.assigns.game_id, fn game ->
        Amazonki.start_game(game)
      end)
    end

    {:noreply, socket}
  end

  def handle_event("player_clicked", %{"player" => player_string}, socket) do
    GameServer.execute(socket.assigns.game_id, fn game ->
      Amazonki.choose_door(game, player_string |> String.to_atom())
    end)

    {:noreply, socket}
  end

  def handle_event("key_clicked", %{"key" => key}, socket) do
    case key do
      "m" -> handle_event("move_clicked", nil, socket)
      "Escape" -> handle_event("cancel_clicked", nil, socket)
      "~" -> handle_event("toggle_console_open", nil, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_console_open", _, socket) do
    {:noreply, assign(socket, console_open?: !socket.assigns.console_open?)}
  end

  def handle_event("toggle_game_state_open", _, socket) do
    {:noreply, assign(socket, game_state_open?: !socket.assigns.game_state_open?)}
  end

  def handle_info({:new_game_state, game}, socket) do
    {:noreply, socket |> assign(game: game)}
  end

  def can_join(game, player) do
    length(game.players) <= 6 and !Enum.member?(game.players, player)
  end
end
