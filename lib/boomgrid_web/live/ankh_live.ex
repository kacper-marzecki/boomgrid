defmodule BoomWeb.AnkhLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS
  require Logger

  def render(assigns) do
    ~H"""
    <pre style="overflow: scroll; height: 200px;">
    <%= inspect(assigns, pretty: true) %>
    </pre>
    <style>
      .card-row{
        <%!-- display: flex;
        justify-content: center;
        width: 100%;
        flex-wrap: wrap;
        gap: 1em;
        padding: 1em 0; --%>
      }

      .rpgui-content * {
        image-rendering: unset;
      }
    </style>
    <div class="rpgui-content" phx-window-keyup="key_clicked">
      <div class="flex flex-row h-screen  w-screen px-6 gap-4">
        <div class="framed flex flex-col justify-center w-1/2 h-full ">
          <%!-- UI  --%>
          <div class="flex h-[55%]">
            <%!-- Gracze  --%>
            <div class="framed-grey w-[30%] ">
              <%!-- Jeden gracz  --%>
              <div
                :for={player <- Map.keys(@game.money)}
                class="framed-grey cursor-rpg"
                phx-click={JS.push("player_clicked", value: %{player: player})}
              >
                <p><%= player %> <%= @game.money[player] %> <%= @game.colors[player] %></p>
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
              <%= case @selected do %>
                <% nil -> %>
                  <div class="mx-3 flex flex-col items-center justify-between">
                    <button
                      :for={deck <- built_in_decks()}
                      type="button"
                      class={"rpgui-button w-full #{deck == @displayed_deck && "golden"}"}
                      phx-click={JS.push("deck_clicked", value: %{deck_id: deck})}
                    >
                      <p>
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
                  </div>
                <% {:card, card} -> %>
                  <div class="w-1/2">
                    <.card class="transition hover:scale-[1.5] hover:translate-y-4" card={card} />
                  </div>
                  <div class="mx-3 flex flex-col gap-5 items-center justify-center w-1/2">
                    <%!-- PRZENIEŚ KARTE --%>
                    <%= case @action do %>
                      <% {:move_card, card, nil} -> %>
                        <button
                          :for={deck <- what_decks_can_it_move_to?(card)}
                          type="button"
                          class="rpgui-button w-1/2"
                          phx-click={JS.push("card_move_target_chosen", value: %{deck_id: deck})}
                        >
                          <p><%= deck_display_name(deck) %></p>
                        </button>
                      <% {:move_card, _card, _deck} -> %>
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
                      <% _ -> %>
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
                    <% end %>

                    <div>
                      <button type="button" class="rpgui-button" phx-click={JS.push("cancel_clicked")}>
                        <p>Anuluj</p>
                      </button>
                    </div>
                  </div>
              <% end %>
            </div>
          </div>
          <%!-- aktualna tura ? --%>
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
            style="
            height: 100%;
            width: 100%;
            /* do ustawiania `position: absolute` elementow */
            position: relative;
            /* żeby częściowo widoczne elementy były obcinane */
            overflow: hidden;
            /* background */
            background-image: url('/images/floor.png');
            background-repeat: repeat;
          "
          >
            <%= for entity <- @entities do %>
              <%= to_html(entity, @viewport_anchor, @viewport_size, @selected_entity_id) %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    <script src="https://unpkg.com/panzoom@9.4.0/dist/panzoom.min.js">
    </script>
    <script>
      var element = document.querySelector('#board')
      window.boardPanzoom = panzoom(element)
    </script>
    """
  end

  def directional_button(assigns) do
    ~H"""
    <button
      type="button"
      class="rpgui-button"
      phx-click={JS.push("map_move_clicked", value: %{direction: @direction})}
    >
      <p>X</p>
    </button>
    """
  end

  def card(assigns) do
    # nie wiem czemu ale class="inline-block" nie nadaje `display: inline-block;`
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

  def to_html(entity, viewport_anchor, viewport_size, selected_entity_id) do
    case entity do
      %{sprite: sprite, position: entity_position, id: id} ->
        # bottom, left, width

        assigns = %{
          id: id,
          left: (entity_position.x - viewport_anchor.x) / viewport_size * 100,
          bottom: (entity_position.y - viewport_anchor.y) / viewport_size * 100,
          height: sprite.size / viewport_size * 100,
          sprite_url: sprite.url,
          selected?: selected_entity_id == id,
          entity_position: entity_position,
          sprite_size: sprite.size
        }

        ~H"""
        <div
          style={"position: absolute; left: #{@left}%; bottom: #{@bottom}%;  width: max-content; height: #{@height}%; #{@selected? && "background-color: white;"}"}
          phx-click={JS.push("entity_clicked", value: %{target: "#{@id}"})}
          title={"#{inspect(@entity_position)} #{@sprite_size}"}
        >
          <img src={@sprite_url} style="height: 100%; width: auto;" class={[@selected? && "shimmer"]} />
        </div>
        """

      _ ->
        nil
    end
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
    entities = mock_entities()
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
          selected: nil,
          action: nil,
          displayed_deck: :table,
          # BOARD assigns
          viewport_anchor: %{x: 0, y: 0, z: 0},
          viewport_size:
            entities |> Enum.map(fn entity -> entity[:sprite][:size] || 0 end) |> Enum.max(),
          entities: entities,
          selected_entity_id: nil,
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
    {:noreply, socket |> assign(selected: {:card, card}, action: nil)}
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
        {:noreply, socket |> assign(displayed_deck: player)}
    end
  end

  def handle_event("play_card", %{"card_id" => card_id}, socket) do
    if can_play(socket.assigns.game, socket.assigns.player, card_id) do
      Boom.GameServer.execute(socket.assigns.game_id, fn game ->
        Boom.Ankh.move_card_to_deck(game, card_id, :table)
      end)
    end

    {:noreply, socket |> assign(selected: nil)}
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

    {:noreply, socket |> assign(action: nil, selected: nil)}
  end

  def handle_event("place_token_clicked", _payload, socket) do
    {:noreply, socket |> assign(selected: nil, action: {:token_placement, nil})}
  end

  @doc """
  token_id - color_type
  e.g. troll blue_agent red_building disturbance
  """
  def handle_event("token_placement_token_chosen", %{"token" => token_id}, socket) do
    {:noreply, socket |> assign(selected: nil, action: {:token_placement, nil})}
  end

  def handle_event(
        "entity_clicked",
        %{"target" => id, "x" => clicked_x_percent, "y" => clicked_y_percent} = payload,
        socket
      ) do
    IO.inspect(payload, label: "entity_clicked")
    IO.inspect(socket.assigns)
    {id, _} = Integer.parse(id)

    clicked_entity = get_entity_by_id(socket, id)

    move_entity = fn moving_entity_id ->
      socket.assigns.entities
      |> Enum.map(fn
        %{id: ^moving_entity_id} = entity ->
          %{z: z} = clicked_entity.position
          moving_entity = get_entity_by_id(socket, moving_entity_id)

          %{x: anchor_x, y: anchor_y} = socket.assigns.viewport_anchor

          x =
            clicked_x_percent / 100 * socket.assigns.viewport_size + anchor_x +
              -0.5 * moving_entity.sprite.size

          y =
            clicked_y_percent / 100 * socket.assigns.viewport_size + anchor_y +
              -0.5 * moving_entity.sprite.size

          position =
            %{x: x, y: y, z: z}
            |> IO.inspect()

          Map.put(entity, :position, position)

        other ->
          other
      end)
    end

    socket =
      case {socket.assigns.mode, clicked_entity} do
        {:normal, %{selectable: true}} ->
          assign(socket, selected_entity_id: id)

        # select entity
        {{:move, moving_entity_id}, %{background: true}} ->
          updated_entities = move_entity.(moving_entity_id)
          assign(socket, entities: updated_entities)

        {{:move, moving_entity_id}, %{id: moving_entity_id}} ->
          updated_entities = move_entity.(moving_entity_id)
          assign(socket, entities: updated_entities)

        _ ->
          assign(socket, selected_entity_id: nil, mode: :normal)
      end

    {:noreply, socket}
  end

  def handle_event("map_move_clicked", %{"direction" => direction}, socket) do
    IO.inspect(direction)

    shift_size = socket.assigns[:viewport_size] / 4
    shift_x = direction["x"] * shift_size
    shift_y = direction["y"] * shift_size

    anchor = socket.assigns.viewport_anchor
    viewport_anchor = %{x: anchor.x + shift_x, y: anchor.y + shift_y}

    {:noreply, socket |> assign(viewport_anchor: viewport_anchor)}
  end

  def handle_event("map_zoom_clicked", %{"direction" => direction}, socket) do
    rate =
      case direction do
        "in" -> 0.9
        "out" -> 1.1
      end

    viewport_size = max(socket.assigns[:viewport_size] * rate, 50)

    {:noreply, socket |> assign(viewport_size: viewport_size)}
  end

  def handle_event("move_clicked", _payload, socket) do
    socket =
      case {socket.assigns.selected_entity_id, socket.assigns.mode} do
        {_, {:move, _}} -> assign(socket, mode: :normal)
        {nil, _} -> socket
        {selected_entity_id, :normal} -> assign(socket, mode: {:move, selected_entity_id})
      end

    {:noreply, socket}
  end

  def handle_event("cancel_clicked", _payload, socket) do
    {:noreply, socket |> assign(selected: nil, action: nil)}
  end

  def handle_event("key_clicked", %{"key" => key}, socket) do
    case key do
      "m" -> handle_event("move_clicked", nil, socket)
      "Escape" -> handle_event("cancel_clicked", nil, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:new_game_state, game}, socket) do
    {:noreply, socket |> assign(game: game)}
  end

  def get_entity_by_id(socket, id) do
    socket.assigns.entities
    |> Enum.find(fn entity -> entity.id == id end)
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

  def gen_id(), do: System.unique_integer([:positive, :monotonic])

  # TODO zoom nie dziala
  def mock_entities() do
    sprites_and_background = [
      %{
        sprite: %{url: "/images/ankh_morpork_plansza.jpg", size: 500},
        position: %{x: 0, y: 0, z: 0},
        id: gen_id(),
        background: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 20},
        position: %{x: 0, y: 0, z: 0},
        id: gen_id(),
        selectable: true
      },
      %{
        sprite: %{url: "/images/action_1.png", size: 20},
        position: %{x: 50, y: 50, z: 0},
        id: gen_id(),
        selectable: true
      }
    ]

    sprites_and_background
  end
end
