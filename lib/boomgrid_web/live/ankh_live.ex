defmodule BoomWeb.AnkhLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS
  require Logger

  def render(assigns) do
    ~H"""
    <div id="debug_div"></div>
    <pre style="overflow: scroll; height: 200px;">
    <%= inspect(assigns, pretty: true) %>
    </pre>
    <div class="rpgui-content" phx-window-keyup="key_clicked">
      <div class="flex flex-row h-screen  w-screen px-6 gap-4">
        <div class="framed flex flex-col justify-center w-1/2 h-full ">
          <%!-- UI  --%>
          <div class="flex h-[55%]">
            <%!-- GRACZE  --%>
            <div class="framed-grey w-[30%] ">
              <div
                :for={player <- Map.keys(@game.money)}
                class="framed-grey cursor-rpg"
                phx-click={JS.push("player_clicked", value: %{player: player})}
              >
                <p>
                  <%= player %> $<%= @game.money[player] %>
                  <span
                    class="h-[20px] w-[20px] inline-block"
                    style={"background-color: #{@game.colors[player]};"}
                  >
                  </span>
                </p>
              </div>
              <button
                :if={can_join(@game, @player)}
                type="button"
                class="rpgui-button"
                phx-click="join_game"
              >
                <p>Dołącz</p>
              </button>
            </div>
            <%!-- OPCJE --%>
            <div class="framed-grey w-[70%] h-full flex flex-row justify-around">
              <%= case @action do %>
                <% nil -> %>
                  <div class="mx-3 flex flex-col items-center justify-between">
                    <button
                      :for={deck <- built_in_decks()}
                      type="button"
                      class={"rpgui-button w-full #{deck == @displayed_deck && "golden"}"}
                      phx-click={JS.push("deck_clicked", value: %{deck_id: deck})}
                    >
                      <p style="text-align:justify;">
                        <span style="font-size: 2em !important;">♧</span> <%= deck_display_name(deck) %>
                      </p>
                    </button>
                  </div>
                  <div class="mx-3 flex flex-col items-center justify-between ">
                    <button
                      type="button"
                      class="rpgui-button w-full"
                      phx-click={JS.push("place_token_clicked")}
                    >
                      <p>pionek</p>
                    </button>
                    <button
                      type="button"
                      class="rpgui-button w-full"
                      data-confirm={"Potasować #{deck_display_name(@displayed_deck)}?"}
                      phx-click={JS.push("shuffle_deck_clicked")}
                    >
                      <p>potasuj</p>
                    </button>
                    <button
                      :if={!Enum.empty?(@game.decks[:table])}
                      type="button"
                      class="rpgui-button w-full"
                      phx-click={JS.push("end_turn_clicked")}
                    >
                      <p>Koniec tury</p>
                    </button>
                  </div>
                <% {:player_selected, player} -> %>
                  <div class="flex flex-col justify-around items-center">
                    <div class="flex flex-row justify-around">
                      <button
                        :for={amount <- [-1, +1]}
                        type="button"
                        class="rpgui-button "
                        phx-click={
                          JS.push("change_player_money", value: %{diff: amount, player: player})
                        }
                      >
                        <p><%= amount %> $</p>
                      </button>
                    </div>
                    <.cancel_button />
                  </div>
                <% {:token_selected, token} -> %>
                  <div class="flex flex-col justify-around items-center">
                    <button
                      type="button"
                      class="rpgui-button "
                      phx-click={JS.push("remove_token", value: %{token_id: token.id})}
                    >
                      <p>usuń</p>
                    </button>
                    <.cancel_button />
                  </div>
                <% {:card_view, card} -> %>
                  <div class="w-1/2">
                    <.card class="transition hover:scale-[1.5] hover:translate-y-4" card={card} />
                  </div>
                  <div class="mx-3 flex flex-col gap-5 items-center justify-center w-1/2">
                    <%!-- ZAGRAJ KARTE --%>
                    <button
                      :if={can_play(@game, @player, card.id)}
                      type="button"
                      class="rpgui-button w-1/2"
                      phx-click={JS.push("play_card", value: %{card_id: card.id})}
                    >
                      <p>Zagraj</p>
                    </button>
                    <%!-- PRZENIEŚ KARTE --%>
                    <button
                      type="button"
                      class="rpgui-button w-1/2"
                      phx-click={JS.push("move_card", value: %{card_id: card.id})}
                    >
                      <p>Przenieś</p>
                    </button>
                    <.cancel_button />
                  </div>
                <% {:move_card, card, nil} -> %>
                  <div class="w-1/2">
                    <.card class="transition hover:scale-[1.5] hover:translate-y-4" card={card} />
                  </div>
                  <div class="mx-3 flex flex-col gap-5 items-center justify-center w-1/2">
                    <%!-- PRZENIEŚ KARTE --%>
                    <button
                      :for={deck <- what_decks_can_it_move_to?(card)}
                      type="button"
                      class="rpgui-button w-1/2"
                      phx-click={JS.push("card_move_target_chosen", value: %{deck_id: deck})}
                    >
                      <p><%= deck_display_name(deck) %></p>
                    </button>
                    <.cancel_button />
                  </div>
                <% {:move_card, card, _deck} -> %>
                  <div class="w-1/2">
                    <.card class="transition hover:scale-[1.5] hover:translate-y-4" card={card} />
                  </div>
                  <div class="mx-3 flex flex-col gap-5 items-center justify-center w-1/2">
                    <button
                      :for={
                        {position, position_text} <- [
                          {"first", "Na wierzch"},
                          {"last", "Na spód"},
                          {"random", "Wtasuj"}
                        ]
                      }
                      type="button"
                      class="rpgui-button w-1/2"
                      phx-click={
                        JS.push("card_move_target_position_chosen", value: %{position: position})
                      }
                    >
                      <p><%= position_text %></p>
                    </button>
                    <.cancel_button />
                  </div>
                <% {:token_placement, nil} -> %>
                  <div class="mx-3 flex flex-col gap-5 items-center justify-center w-1/2">
                    <button
                      :for={type <- [:disturbance, :demon, :troll]}
                      type="button"
                      class="rpgui-button w-1/2"
                      phx-click={JS.push("token_placement_token_chosen", value: %{token: type})}
                    >
                      <p><%= token_type_display_name(type) %></p>
                    </button>
                    <.cancel_button />
                  </div>
                <% {:token_placement, token_type} -> %>
                  <p>Kliknij na planszę żeby położyć <%= token_type_display_name(token_type) %></p>
                  <.cancel_button />
              <% end %>
            </div>
          </div>
          <%!-- ZAZNACZONA TALIA --%>
          <div class="h-[5%] flex items-center">
            <p><%= deck_display_name(@displayed_deck) %></p>
          </div>
          <div class="whitespace-nowrap overflow-x-scroll h-[20%]">
            <%= for card <- @game.decks[@displayed_deck] do %>
              <.card card={card} reverse={@displayed_deck not in [:table, @player]} />
            <% end %>
          </div>
          <%!-- Reka gracza  --%>
          <div class="whitespace-nowrap overflow-x-scroll h-[20%]">
            <%= for card <- @game.decks[@player] || [] do %>
              <.card card={card} />
            <% end %>
          </div>
        </div>
        <div class="framed overflow-hidden w-1/2 h-full">
          <div
            id="board"
            phx-hook="PanzoomHook"
            style="
            height: 1000px;
            width: 1000px;
            /* do ustawiania `position: absolute` elementow */
            position: relative;
            /* żeby częściowo widoczne elementy były obcinane */
            overflow: hidden;
            /* background */
            background-image: url('/images/floor.png');
            background-repeat: repeat;
          "
          >
            <%= for token <-@game.tokens  do %>
              <% is_selected = match?({:token_selected, ^token}, @action) %>
              <%= to_html(token, @viewport_anchor, @viewport_size, is_selected) %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    <script src="https://unpkg.com/panzoom@9.4.0/dist/panzoom.min.js" />
    """
  end

  def cancel_button(assigns) do
    ~H"""
    <div>
      <button type="button" class="rpgui-button" phx-click={JS.push("cancel_clicked")}>
        <p>Anuluj</p>
      </button>
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
      style="display: inline-block; "
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
      phx-hook="BoardToken"
      id={"token_#{@id}"}
      style={"position: absolute; left: #{@left}%; bottom: #{@bottom}%;  width: max-content; height: #{@height}%; #{@selected? && "background-color: white;"}"}
      phx-click={JS.push("token_clicked", value: %{target: "#{@id}"})}
    >
      <img src={@sprite_url} style="height: 100%; width: auto;" class={[@selected? && "shimmer"]} />
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
          player: player,
          game_id: game_id,
          # BOARD assigns
          action: nil,
          displayed_deck: :table,
          # BOARD assigns
          viewport_anchor: %{x: 0, y: 0, z: 0},
          viewport_size:
            game.tokens
            |> Enum.find(fn
              %{background: true} -> true
              _ -> false
            end)
            |> case do
              background -> background.sprite.size
            end,
          mode: :normal
        )
      else
        {:error, e} ->
          err = "Error while starting up Ankh LiveView: #{inspect(e)}"
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
        Boom.Ankh.add_player(game, socket.assigns.player)
      end)
    end

    {:noreply, socket}
  end

  def handle_event("card_clicked", %{"card_id" => card_id}, socket) do
    card = Boom.Ankh.find_card(socket.assigns.game, card_id)
    {:noreply, socket |> assign(action: {:card_view, card})}
  end

  def handle_event("deck_clicked", %{"deck_id" => deck_string}, socket) do
    deck = String.to_existing_atom(deck_string)

    {:noreply, socket |> assign(displayed_deck: deck)}
  end

  def handle_event("player_clicked", %{"player" => player_string}, socket) do
    case socket.assigns.action do
      {:move_card, card, nil} when not is_nil(card) ->
        handle_event("card_move_target_chosen", %{"deck_id" => player_string}, socket)

      _ ->
        player = String.to_existing_atom(player_string)
        {:noreply, socket |> assign(displayed_deck: player, action: {:player_selected, player})}
    end
  end

  def handle_event("play_card", %{"card_id" => card_id}, socket) do
    if can_play(socket.assigns.game, socket.assigns.player, card_id) do
      Boom.GameServer.execute(socket.assigns.game_id, fn game ->
        Boom.Ankh.move_card_to_deck(game, card_id, :table)
      end)
    end

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
      Boom.Ankh.move_card_to_deck(game, card.id, deck, position)
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
      Boom.Ankh.money_change(game, player, diff)
    end)

    {:noreply, socket}
  end

  def handle_event("remove_token", %{"token_id" => token_id}, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.remove_token(game, token_id)
    end)

    {:noreply, socket |> assign(action: nil)}
  end

  def handle_event(
        "token_clicked",
        %{"target" => id, "x" => clicked_x_percent, "y" => clicked_y_percent} = _payload,
        socket
      ) do
    {id, _} = Integer.parse(id)

    clicked_token = get_token_by_id(socket, id)

    %{x: anchor_x, y: anchor_y} = socket.assigns.viewport_anchor

    clicked_at = %{
      x: clicked_x_percent / 100 * socket.assigns.viewport_size + anchor_x,
      y: clicked_y_percent / 100 * socket.assigns.viewport_size + anchor_y
    }

    socket =
      case {socket.assigns.action, clicked_token} do
        {{:token_placement, token_type}, %{background: true}} ->
          token_template = Boom.Ankh.new_token(token_type)
          offset = -0.5 * token_template.sprite.size

          new_token =
            token_template
            |> Map.merge(%{
              position: %{
                x: clicked_at.x + offset,
                y: clicked_at.y + offset
              },
              selectable: true
            })

          Boom.GameServer.execute(socket.assigns.game_id, fn game ->
            Boom.Ankh.place_token(game, new_token)
          end)

          assign(socket, action: nil)

        {{:token_selected, selected_token}, %{background: true}} ->
          offset = -0.5 * selected_token.sprite.size

          target_position = %{
            x: clicked_at.x + offset,
            y: clicked_at.y + offset
          }

          Boom.GameServer.execute(socket.assigns.game_id, fn game ->
            Boom.Ankh.move_token(
              game,
              selected_token.id,
              target_position.x,
              target_position.y
            )
          end)

          assign(socket, action: nil)

        {{:token_selected, %{id: id} = selected_token}, %{id: id}} ->
          IO.inspect("asd")
          offset = -0.5 * selected_token.sprite.size

          target_position = %{
            x: clicked_at.x + offset,
            y: clicked_at.y + offset
          }

          Boom.GameServer.execute(socket.assigns.game_id, fn game ->
            Boom.Ankh.move_token(
              game,
              selected_token.id,
              target_position.x,
              target_position.y
            )
          end)

          assign(socket, action: nil)

        {_, %{selectable: true}} ->
          assign(socket, action: {:token_selected, clicked_token})

        _ ->
          IO.inspect("ZXC")

          assign(socket, action: nil)
      end

    {:noreply, socket}
  end

  def handle_event("end_turn_clicked", _payload, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.move_all_cards_from_deck_to_deck(game, :table, :graveyard)
    end)

    {:noreply, socket}
  end

  def handle_event("shuffle_deck_clicked", _payload, socket) do
    Boom.GameServer.execute(socket.assigns.game_id, fn game ->
      Boom.Ankh.shuffle_deck(game, socket.assigns.displayed_deck)
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
      _ -> {:noreply, socket}
    end
  end

  def handle_event("debug", payload, socket) do
    Logger.debug(inspect(payload))
    {:noreply, socket}
  end

  def handle_info({:new_game_state, game}, socket) do
    {:noreply, socket |> assign(game: game)}
  end

  def get_token_by_id(socket, id) do
    socket.assigns.game.tokens
    |> Enum.find(fn token -> token.id == id end)
  end

  def can_join(game, player) do
    players = Map.keys(game.money)
    length(players) <= 4 and !Enum.member?(players, player)
  end

  def can_play(game, player, card_id) do
    player_hand = game.decks[player] || []
    Enum.find(player_hand, fn card -> card.id == card_id end)
  end

  def get_players(game) do
    Map.keys(game.money)
  end

  def what_decks_can_it_move_to?(card) do
    case card.type do
      :action -> [:actions, :graveyard]
      :event -> [:events]
      :character -> [:characters]
      :district -> [:districts]
    end
  end

  def placeable_tokens(game) do
    colorful_tokens =
      for color <- Map.values(game.colors),
          type <- ["agent", "building"] do
        "#{color}_#{type}"
      end

    colorful_tokens ++ ["troll", "disturbance", "demon"]
  end

  def built_in_decks do
    Boom.Ankh.new_game().decks
    |> Map.keys()
  end

  def deck_display_name(deck_id) do
    case deck_id do
      :graveyard -> "odrzucone"
      :events -> "zdarzenia"
      :actions -> "akcje"
      :characters -> "postacie"
      :table -> "stół"
      :districts -> "dzielnice"
      other -> other
    end
  end

  def token_type_display_name(token_type) do
    case token_type do
      :demon -> "demon"
      :disturbance -> "niepokoje"
      :troll -> "troll"
    end
  end

  def gen_id(), do: System.unique_integer([:positive, :monotonic])

  def starting_tokens() do
    [
      %{
        sprite: %{url: "/images/ankh_morpork_plansza.jpg", size: 500},
        position: %{x: 0, y: 0},
        id: gen_id(),
        background: true
      }
      # ,%{
      #   sprite: %{url: "/images/action_1.png", size: 20},
      #   position: %{x: 250, y: 250},
      #   id: gen_id(),
      #   selectable: true
      # }
    ]
  end
end
