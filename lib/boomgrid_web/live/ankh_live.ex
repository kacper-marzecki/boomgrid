defmodule BoomWeb.AnkhLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <pre style="overflow: scroll; height: 200px;">
    <%= inspect(assigns, pretty: true) %>
    </pre>
    <style>
    </style>
    <div class="rpgui-content" phx-window-keyup="key_clicked">
      <div class="grid grid-cols-2" style="height: 100vh;">
        <div class="rpgui-container framed" style="height: 90vh; width: 90vh;">
          <%!-- UI  --%>
          <div style="height: 80%;">
            <%!-- Gracze  --%>
            <div class="rpgui-container framed-grey w-1/4" style="float: left;">
              <%!-- Jeden gracz  --%>
              <div class="rpgui-container framed-grey">
                <p>
                  kacper 15$ <span style="cursor: pointer;">+</span>
                  <span style="cursor: pointer;">-</span>
                </p>
              </div>
            </div>
            <div class="rpgui-container framed-grey w-3/4 " style="float: left;">
              <p>gracze</p>
            </div>
          </div>
          <%!-- Reka gracza  --%>
          <hr />
          <div style="overflow-x: scroll;  height: 20%;  white-space: nowrap;  ">
            <%!-- TODO: dodać karty katóre aktualnie masz w reku   --%>
            <img style="display: inline-block;  height: 100%; " src="/images/action_1.png" />
            <img style="display: inline-block;  height: 100%; " src="/images/action_1.png" />
            <img style="display: inline-block;  height: 100%; " src="/images/action_1.png" />
            <img style="display: inline-block;  height: 100%; " src="/images/action_1.png" />
            <img style="display: inline-block;  height: 100%; " src="/images/action_1.png" />
          </div>
        </div>
        <div
          class="rpgui-container framed"
          style="
        height: 90vh;
        width: 90vh;
        overflow: hidden;
        "
        >
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

  # TODO zoom nie dziala
  def mock_entities(),
    do: [
      %{
        sprite: %{url: "/images/ankh_morpork_plansza.jpg", size: 500},
        position: %{x: 0, y: 0, z: 0},
        id: 1,
        background: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 20},
        position: %{x: 0, y: 0, z: 0},
        id: 2,
        selectable: true
      },
      %{
        sprite: %{url: "/images/action_1.png", size: 20},
        position: %{x: 50, y: 50, z: 0},
        id: 3,
        selectable: true
      }
    ]
end
