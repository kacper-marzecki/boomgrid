defmodule Boom.Id do
  def gen_id(), do: System.unique_integer([:positive, :monotonic])
end
