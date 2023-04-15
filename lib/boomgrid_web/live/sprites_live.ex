defmodule BoomWeb.SpritesLive do
  use BoomWeb, :live_view

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <pre style="overflow: scroll; height: 200px;">
    <%= inspect(assigns, pretty: true) %>
    </pre>
    <div class="rpgui-content">
      <div class="grid grid-cols-2" style="height: 100vh;">
        <div class="rpgui-container framed" style="height: 90vh; width: 90vh;">
          <button
            :if={!match?({:add, _}, @mode)}
            type="button"
            class="rpgui-button"
            phx-click="add_clicked"
          >
            +
          </button>
          <button
            :if={!match?(:normal, @mode)}
            type="button"
            class="rpgui-button"
            phx-click="cancel_clicked"
          >
            Cancel
          </button>
          <table style="width: 100%;">
            <thead>
              <th>
                <h3>id</h3>
              </th>
              <th>
                <h3>name</h3>
              </th>
              <th></th>
            </thead>
            <tbody>
              <%= for image <- @images do %>
                <tr>
                  <td>
                    <p><%= image.id %></p>
                  </td>
                  <td>
                    <p><%= image.name %></p>
                  </td>
                  <td>
                    <p class="rpgui-link" phx-click="delete_clicked">Delete</p>
                  </td>
                </tr>
              <% end %>
            </tbody>
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
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    images = [
      %Boom.Image{name: "name 1", bytes: nil, id: 1},
      %Boom.Image{name: "name 2", bytes: nil, id: 2},
      %Boom.Image{name: "name 3", bytes: nil, id: 3},
      %Boom.Image{name: "name 4", bytes: nil, id: 4}
    ]

    {:ok, socket |> assign(images: images, mode: :normal)}
  end

  def handle_event("add_clicked", _payload, socket) do
    {:noreply, socket |> assign(mode: {:add, %{}})}
  end

  def handle_event("cancel_clicked", _payload, socket) do
    {:noreply, socket |> assign(mode: :normal)}
  end
end
