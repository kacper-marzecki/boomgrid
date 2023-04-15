defmodule Boom.BoardToken do
  use Ecto.Schema

  schema "board_tokens" do
    field(:name, :string)
    field(:sprite, :binary)
    field(:sprite_name, :binary)
    field(:password, :string, redact: true)
    timestamps()
  end
end

defmodule Boom.Image do
  use Ecto.Schema
  import Ecto.Changeset

  schema "images" do
    field(:name, :string)
    field(:bytes, :binary)
  end

  @doc false
  def changeset(module \\ %__MODULE__{}, attrs) do
    module
    |> cast(attrs, [:name, :bytes])
    |> validate_required([:name, :bytes])
  end
end

defmodule Boom.BoardGame do
  use Ecto.Schema

  schema "board_game" do
    field(:entities, {:array, :map}, default: [])
    timestamps()
  end
end
