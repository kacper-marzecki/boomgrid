defmodule Boom.Repo do
  use Ecto.Repo,
    otp_app: :boomgrid,
    adapter: Ecto.Adapters.Postgres
end
