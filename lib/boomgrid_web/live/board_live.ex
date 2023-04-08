defmodule BoomWeb.BoardLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <link
      phx-track-static
      rel="stylesheet"
      href={Routes.static_path(@socket, "/assets/rpgui/rpgui.css")}
    />
    <script
      defer
      phx-track-static
      type="text/javascript"
      src={Routes.static_path(@socket, "/assets/rpgui/rpgui.js")}
    >
    </script>
    <style>
        .rpgui-content {
          position: unset;
        }
        .rpgui-container {
          position: unset;
        }

        .shimmer {
          -webkit-mask:linear-gradient(-60deg,#000 30%,#0005,#000 70%) right/350% 100%;
          background-repeat: no-repeat;
          animation: shimmer 1.5s infinite;
          background-color: white;
      }

      @keyframes shimmer {
         100% {-webkit-mask-position:left}
       }
    </style>
    <pre style="overflow: scroll; height: 200px;">
    <%= inspect(assigns, pretty: true) %>
    </pre>
    <div class="rpgui-content" phx-window-keyup="key_clicked">
      <div class="grid grid-cols-2" style="height: 100vh;">
        <div class="rpgui-container framed" style="height: 90vh; width: 90vh;">
          <p>This is a basic rpgui-container with "framed" class.</p>
          <button
            type="button"
            class="rpgui-button"
            phx-click={JS.push("map_zoom_clicked", value: %{direction: "in"})}
          >
            <p>+</p>
          </button>
          <button
            type="button"
            class="rpgui-button"
            phx-click={JS.push("map_zoom_clicked", value: %{direction: "out"})}
          >
            <p>-</p>
          </button>
          <table>
            <tr>
              <td><%= directional_button(%{direction: %{x: -1, y: 1}}) %></td>
              <td><%= directional_button(%{direction: %{x: 0, y: 1}}) %></td>
              <td><%= directional_button(%{direction: %{x: 1, y: 1}}) %></td>
            </tr>
            <tr>
              <td><%= directional_button(%{direction: %{x: -1, y: 0}}) %></td>
              <td></td>
              <td><%= directional_button(%{direction: %{x: 1, y: 0}}) %></td>
            </tr>
            <tr>
              <td><%= directional_button(%{direction: %{x: -1, y: -1}}) %></td>
              <td><%= directional_button(%{direction: %{x: 0, y: -1}}) %></td>
              <td><%= directional_button(%{direction: %{x: 1, y: -1}}) %></td>
            </tr>
          </table>
          <button
            :if={@selected_entity_id}
            type="button"
            class={["rpgui-button", match?({:move, _}, @mode) && "shimmer"]}
            phx-click={JS.push("move_clicked")}
          >
            <p>move</p>
          </button>
        </div>
        <div
          id="board"
          class="rpgui-container framed"
          style="
        height: 90vh;
        width: 90vh;
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
      %{sprite: sprite, position: entity_position, id: id}
      when entity_position.z <= viewport_anchor.z ->
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
    Process.send_after(self(), :moveBackground, 1000)
    entities = mock_entities()

    {:ok,
     socket
     |> assign(
       backgroundPosition: 0,
       viewport_anchor: %{x: 0, y: 0, z: 0},
       viewport_size:
         entities |> Enum.map(fn entity -> entity[:sprite][:size] || 0 end) |> Enum.max(),
       entities: entities,
       selected_entity_id: nil,
       # :move
       mode: :normal
     )}
  end

  def handle_info(:moveBackground, socket) do
    Process.send_after(self(), :moveBackground, 1000)
    {:noreply, assign(socket, backgroundPosition: socket.assigns.backgroundPosition + 10)}
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
    viewport_anchor = %{x: anchor.x + shift_x, y: anchor.y + shift_y, z: anchor.z}

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
        sprite: %{url: "/images/battlemap.jpeg", size: 300},
        position: %{x: 0, y: 0, z: 0},
        id: 1,
        background: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 50},
        position: %{x: 0, y: 0, z: 0},
        id: 2,
        selectable: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 50},
        position: %{x: 50, y: 50, z: 0},
        id: 3,
        selectable: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 1},
        position: %{x: 200, y: 50, z: 0},
        id: 4,
        selectable: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 15},
        position: %{x: -10, y: 10, z: 0},
        id: 5,
        selectable: true
      }
    ]
end
