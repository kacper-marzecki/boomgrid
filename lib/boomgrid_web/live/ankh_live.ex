defmodule BoomWeb.AnkhLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <pre style="overflow: scroll; height: 200px;">
    <%= inspect(assigns, pretty: true) %>
    </pre>
    <style>
      .card-row{
        display: flex;
        justify-content: center;
        width: 100%;
        flex-wrap: wrap;
        gap: 1em;
        padding: 1em 0;
      }

      .rpgui-content * {
        image-rendering: unset;
      }
    </style>
    <div class="rpgui-content" phx-window-keyup="key_clicked">
      <div class="grid grid-cols-2 gap-4 min-h-screen w-screen px-6">
        <div class="framed flex flex-col justify-center ">
          <%!-- UI  --%>
          <div class="flex min-h-[400px] h-1/2">
            <%!-- Gracze  --%>
            <div class="framed-grey w-1/4">
              <%!-- Jeden gracz  --%>
              <div class="framed-grey">
                <p>
                  kacper 15$ <button>+</button>
                  <button>-</button>
                </p>
              </div>
            </div>
            <div class="framed-grey w-3/4 h-full flex flex-col justify-between">
              <div>
                <p>menu</p>
              </div>
              <div>
                <button type="button" class="rpgui-button" phx-click={show_tab("karty")}>
                  <p>karty</p>
                </button>
                <button type="button" class="rpgui-button" phx-click={show_tab("pionki")}>
                  <p>pionki</p>
                </button>
                <button type="button" class="rpgui-button" phx-click={show_tab("akcje")}>
                  <p>akcja</p>
                </button>
              </div>
            </div>
          </div>
          <%!-- aktualna tura ? --%>
          <hr />
          <div class="card-row ">
            <%!-- TODO: dodać karty katóre aktualnie masz w reku   --%>
            <.card :for={_ <- 1..5} />
          </div>
          <%!-- Reka gracza  --%>
          <hr />
          <div class="card-row ">
            <%!-- TODO: dodać karty katóre aktualnie masz w reku   --%>
            <.card :for={_ <- 1..5} />
          </div>
        </div>
        <div class="framed overflow-hidden">
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
    ~H"""
    <div class="relative w-[100px] h-[160px] mx-8">
      <img
        class="absolute transition hover:scale-[3.5] hover:translate-y-[-125%]  hover:z-50"
        src="/images/action_1.png"
      />
    </div>
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
          selected?: selected_entity_id == id
        }

        ~H"""
        <div
          style={"position: absolute; left: #{@left}%; bottom: #{@bottom}%;  width: max-content; height: #{@height}%; #{@selected? && "background-color: white;"}"}
          phx-click={JS.push("entity_clicked", value: %{target: "#{@id}"})}
          title={"#{inspect(entity_position)} #{sprite.size}"}
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

  def mount(_params, _session, socket) do
    entities = mock_entities()

    {:ok,
     socket
     |> assign(
       viewport_anchor: %{x: 0, y: 0, z: 0},
       viewport_size:
         entities |> Enum.map(fn entity -> entity[:sprite][:size] || 0 end) |> Enum.max(),
       entities: entities,
       selected_entity_id: nil,
       # :move
       mode: :normal
     )}
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

    # mutacja to zguba wszystkiego
    # pora na ecs
    # maybe_moved_to =
    #   case selected_entity do
    #     nil ->
    #       nil
    #   end

    # case entity do
    #   %{selectable: true} -> id
    #   _ -> nil
    # end

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

  def handle_event("map_move_clicked", %{"direction" => direction}, socket) do
    IO.inspect(direction)

    shift_size = socket.assigns[:viewport_size] / 4
    shift_x = direction["x"] * shift_size
    shift_y = direction["y"] * shift_size

    {x, y, z} = socket.assigns[:viewport_anchor]
    viewport_anchor = {x + shift_x, y + shift_y, z}

    {:noreply, socket |> assign(viewport_anchor: viewport_anchor)}
  end

  def handle_event("key_clicked", %{"key" => key}, socket) do
    case key do
      "m" -> handle_event("move_clicked", nil, socket)
      _ -> {:noreply, socket}
    end
  end

  def get_entity_by_id(socket, id) do
    socket.assigns.entities
    |> Enum.find(fn entity -> entity.id == id end)
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
