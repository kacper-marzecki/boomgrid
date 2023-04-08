defmodule BoomWeb.BoardLive do
  use BoomWeb, :live_view
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <link href="assets/rpgui/rpgui.css" rel="stylesheet" type="text/css" />
    <script src="assets/rpgui/rpgui.js">
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
    <pre>
    <%= inspect(@entities, pretty: true) %>
    </pre>
    <div class="rpgui-content">
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
        </div>
        <div
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
            <%= to_html(entity, @viewport_anchor, @viewport_size, @selected_entity) %>
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

  def to_html(entity, {x, y, z} = _viewport_anchor, viewport_size, selected_entity) do
    case entity do
      %{sprite: sprite, position: {entity_x, entity_y, entity_z}, id: id} when entity_z <= z ->
        # bottom, left, width

        assigns = %{
          id: id,
          left: (entity_x - x) / viewport_size * 100,
          bottom: (entity_y - y) / viewport_size * 100,
          height: sprite.size / viewport_size * 100,
          sprite_url: sprite.url,
          selected?: selected_entity == id
        }

        ~H"""
        <div
          style={"position: absolute; left: #{@left}%; bottom: #{@bottom}%;  width: max-content; height: #{@height}%; #{@selected? && "background-color: white;"}"}
          phx-click={JS.push("entity_clicked", value: %{target: "#{@id}"})}
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
       viewport_anchor: {0, 0, 0},
       viewport_size:
         entities |> Enum.map(fn entity -> entity[:sprite][:size] || 0 end) |> Enum.max(),
       entities: entities,
       selected_entity: nil,
       # :move
       mode: :normal
     )}
  end

  def handle_info(:moveBackground, socket) do
    Process.send_after(self(), :moveBackground, 1000)
    {:noreply, assign(socket, backgroundPosition: socket.assigns.backgroundPosition + 10)}
  end

  def handle_event("entity_clicked", %{"target" => id} = payload, socket) do
    IO.inspect(payload, label: "entity_clicked")
    IO.inspect(socket.assigns)
    {id, _} = Integer.parse(id)

    clicked_entity = get_entity_by_id(socket, id)

    # case mode do
    #   :normal ->
    #   {:move, moving_entity_id} ->
    # end

    selected_entity_id =
      case clicked_entity do
        %{selectable: true} -> id
        _ -> nil
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

    {:noreply, socket |> assign(selected_entity: selected_entity_id)}
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

  def handle_event("map_zoom_clicked", %{"direction" => direction}, socket) do
    rate =
      case direction do
        "in" -> 0.9
        "out" -> 1.1
      end

    viewport_size = max(socket.assigns[:viewport_size] * rate, 50)

    {:noreply, socket |> assign(viewport_size: viewport_size)}
  end

  def handle_event("move_clicked", payload, socket) do
    socket =
      case socket.assigns.selected_entity_id do
        nil -> socket
        selected_entity_id -> assign(socket, mode: {:move, selected_entity_id})
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

  def get_entity_by_id(socket, id) do
    socket.assigns.entities
    |> Enum.find(fn entity -> entity.id == id end)
  end

  # TODO zoom nie dziala
  def mock_entities(),
    do: [
      %{sprite: %{url: "/images/battlemap.jpeg", size: 300}, position: {0, 0, 0}, id: 1},
      %{
        sprite: %{url: "/images/floor.png", size: 150},
        position: {0, 0, 0},
        id: 2,
        selectable: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 50},
        position: {5, 5, 0},
        id: 3,
        selectable: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 1},
        position: {200, 50, 0},
        id: 4,
        selectable: true
      },
      %{
        sprite: %{url: "/images/floor.png", size: 15},
        position: {-10, 10, 0},
        id: 5,
        selectable: true
      }
    ]
end
