defmodule BoomWeb.Components.Rpgui do
  use Phoenix.Component

  attr :rest, :global
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type="button" class={["rpgui-button", @class]} {@rest}>
      <div class="flex flex-row  items-center justify-center">
        <%= render_slot(@inner_block) %>
      </div>
    </button>
    """
  end

  attr :text, :string, required: true
  attr :rest, :global

  def text_button(assigns) do
    ~H"""
    <.button {@rest}>
      <p>
        <%= @text %>
      </p>
    </.button>
    """
  end
end
