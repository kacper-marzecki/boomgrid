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
        <Rpgui.text_button class="float-right" phx-click={JS.push("roll_dice")} text="⚄" />

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
                      <td><%= Boom.Amazonki.count_open_doors(@game, :empty) %></td>
                      <td><%= Boom.Amazonki.count_open_doors(@game, :trap) %></td>
                      <td><%= Boom.Amazonki.count_open_doors(@game, :gold) %></td>
                    </tr>
                    <tr>
                      <td>Hand</td>
                      <td><%= Boom.Amazonki.count_player_doors(@game, @player, :empty) %></td>
                      <td><%= Boom.Amazonki.count_player_doors(@game, @player, :trap) %></td>
                      <td><%= Boom.Amazonki.count_player_doors(@game, @player, :gold) %></td>
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

  def is_selected?(action, token) do
    case action do
      {:token_selected, selected_token} -> selected_token.id == token.id
      _ -> false
    end
  end

  def cancel_button(assigns) do
    ~H"""
    <div>
      <Rpgui.text_button text="Anuluj" phx-click={JS.push("cancel_clicked")} />
    </div>
    """
  end

  def card(assigns) do
    #  nie wiem czemu ale class="inline-block" nie nadaje display: inline-block
    assigns =
      assigns
      |> Phoenix.Component.assign_new(:class, fn _ -> "" end)
      |> Phoenix.Component.assign_new(:reverse, fn _ -> false end)

    ~H"""
    <img
      style="display: inline-block; object-fit: contain;"
      class={"h-[100%] mx-1 #{@class}"}
      src={if @reverse, do: @card.reverse_image, else: @card.image}
      phx-click={JS.push("card_clicked", value: %{card_id: @card.id})}
    />
    """
  end

  def to_html(entity, viewport_anchor, viewport_size, is_selected) do
    %{sprite: sprite, position: entity_position, id: id} = entity

    assigns = %{
      id: id,
      left: (entity_position.x - viewport_anchor.x) / viewport_size * 100,
      bottom: (entity_position.y - viewport_anchor.y) / viewport_size * 100,
      height: sprite.size / viewport_size * 100,
      sprite_url: sprite.url,
      selected?: is_selected
    }

    ~H"""
    <button
      id={"token_#{@id}"}
      style={"position: absolute; left: #{@left}%; bottom: #{@bottom}%;  width: max-content; height: #{@height}%; #{@selected? && "background-color: white;"}"}
      phx-click={JS.push("token_clicked", value: %{target: "#{@id}"})}
    >
      <img
        id={"token_image_#{@id}"}
        src={@sprite_url}
        style="height: 100%; width: auto;"
        class={[@selected? && "shimmer"]}
      />
    </button>
    """
  end

  def show_tab(tab) do
    tabs = ["karty", "pionki", "akcje"]
    tabs_to_hide = Enum.filter(tabs, &(&1 != tab))
    js = JS.show(to: "##{tab}")

    tabs_to_hide
    |> Enum.reduce(js, fn tab_to_hide, js ->
      JS.hide(js, to: "##{tab_to_hide}")
    end)
  end

  def mount(%{"game_id" => game_id}, %{"current_user" => username} = session, socket) do
    player = String.to_atom(username)

    if connected?(socket) do
      Boom.GameServer.subscribe_me!(game_id)
    end

    socket =
      with {:ok, game} <- Boom.GameServer.get_game(game_id) do
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
      Boom.GameServer.execute(socket.assigns.game_id, fn game ->
        Boom.Amazonki.add_player(game, socket.assigns.player)
      end)
    end

    {:noreply, socket}
  end

  def handle_event("start_game", _payload, socket) do
    IO.inspect(socket.assigns.game)

    if Boom.Amazonki.can_start_game?(socket.assigns.game) do
      Boom.GameServer.execute(socket.assigns.game_id, fn game ->
        Boom.Amazonki.start_game(game)
        |> IO.inspect(label: "ASD")
      end)
    end

    {:noreply, socket}
  end

  def handle_event("player_clicked", %{"player" => player_string}, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Amazonki.choose_door(game, player_string |> String.to_atom())
    end)

    {:noreply, socket}
  end

  def handle_event("card_clicked", %{"card_id" => card_id}, socket) do
    %{player: player, game: game} = socket.assigns
    card = Boom.Ankh.find_card(game, card_id)
    deck = Boom.Ankh.find_card_deck(game, card)

    # if !visible_to_player?(game, card, player) do
    #  add_log(socket, "#{player} podejrzał kartę #{card.id} w talii: #{deck} ")
    # end

    {:noreply, socket |> assign(action: {:card_view, card})}
  end

  def handle_event("deck_clicked", %{"deck_id" => deck_string}, socket) do
    deck = String.to_existing_atom(deck_string)

    {:noreply, socket |> assign(displayed_deck: deck)}
  end

  def handle_event("play_card", %{"card_id" => card_id}, socket) do
    game = socket.assigns.game
    card = Boom.Ankh.find_card(game, card_id)

    # if can_play(game, socket.assigns.player, card) do
    #  Boom.GameServer.execute(socket.assigns.game_id, fn game ->
    #    Boom.Ankh.move_card_to_deck(game, card_id, :table, socket.assigns.player)
    #  end)
    # end

    {:noreply, socket |> assign(action: nil)}
  end

  def handle_event("move_card", %{"card_id" => card_id}, socket) do
    card = Boom.Ankh.find_card(socket.assigns.game, card_id)
    {:noreply, socket |> assign(action: {:move_card, card, nil})}
  end

  def handle_event("card_move_target_chosen", %{"deck_id" => deck_string}, socket) do
    deck = String.to_existing_atom(deck_string)
    {:move_card, card, nil} = socket.assigns.action
    {:noreply, socket |> assign(action: {:move_card, card, deck})}
  end

  def handle_event("card_move_target_position_chosen", %{"position" => position}, socket) do
    {:move_card, card, deck} = socket.assigns.action

    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.move_card_to_deck(game, card.id, deck, position, socket.assigns.player)
    end)

    {:noreply, socket |> assign(action: nil)}
  end

  def handle_event("place_token_clicked", _payload, socket) do
    {:noreply, socket |> assign(action: {:token_placement, nil})}
  end

  def handle_event("token_placement_token_chosen", %{"token" => token_type}, socket) do
    {:noreply, socket |> assign(action: {:token_placement, String.to_existing_atom(token_type)})}
  end

  def handle_event("change_player_money", %{"diff" => diff, "player" => player_string}, socket) do
    player = String.to_existing_atom(player_string)

    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.money_change(game, player, diff, socket.assigns.player)
    end)

    {:noreply, socket}
  end

  def handle_event("remove_token", %{"token_id" => token_id}, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.remove_token(game, token_id, socket.assigns.player)
    end)

    {:noreply, socket |> assign(action: nil)}
  end

  def handle_event("draw_card_clicked", _payload, socket) do
    player = socket.assigns.player

    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.move_n_cards_from_deck_to_deck(game, 1, :actions, player, player)
    end)

    {:noreply, socket}
  end

  def handle_event("buy_building_clicked", %{"card_id" => card_id}, socket) do
    %{type: :district} = Boom.Ankh.find_card(socket.assigns.game, card_id)

    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.move_card_to_deck(
        game,
        card_id,
        socket.assigns.player,
        "first",
        socket.assigns.player
      )
    end)

    {:noreply, socket |> assign(action: nil, displayed_deck: :table)}
  end

  def handle_event("end_turn_clicked", _payload, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.move_all_cards_from_deck_to_deck(game, :table, :graveyard, socket.assigns.player)
    end)

    {:noreply, socket}
  end

  def handle_event("shuffle_deck_clicked", _payload, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.shuffle_deck(game, socket.assigns.displayed_deck, socket.assigns.player)
    end)

    {:noreply, socket}
  end

  def handle_event("cancel_clicked", _payload, socket) do
    {:noreply, socket |> assign(action: nil)}
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

  def handle_event("roll_dice", _, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Amazonki.add_log(game, "Rzut kością: #{:rand.uniform(12)}")
    end)

    {:noreply, socket}
  end

  def handle_event("debug", payload, socket) do
    Logger.debug(inspect(payload))
    {:noreply, socket}
  end

  def handle_info({:new_game_state, game}, socket) do
    {:noreply, socket |> assign(game: game)}
  end

  def can_join(game, player) do
    length(game.players) <= 6 and !Enum.member?(game.players, player)
  end

  def gen_id(), do: System.unique_integer([:positive, :monotonic])

  def add_log(socket, log) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Amazonki.add_log(game, log)
    end)
  end
end
