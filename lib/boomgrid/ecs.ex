defmodule Boomgrid.Ecs do
  @moduledoc """
  entity to mapa
  %{id: uuid}
  """
  defstruct systems: [], entities: []

  def get_entities(%__MODULE__{} = ecs, component_types) do
    ecs.entities
    |> Enum.filter(fn _entity ->
      Enum.any?(component_types, fn %{__struct__: struct_module} ->
        struct_module in component_types
      end)
    end)
  end

  # gdzie jest element
  defmodule Position do
    defstruct [:x, :y]
  end

  # w którą stronę się porusza
  defmodule Momentum do
    defstruct [:x, :y]
  end

  defmodule SpellEffect do
    defstruct [:cast_by]
  end

  defmodule InputSystem do
    def process(ecs) do
      ecs.entities
      |> Enum.map(fn
        %{position: %Position{} = _position} = entity -> entity
        other -> other
      end)
    end
  end
end
