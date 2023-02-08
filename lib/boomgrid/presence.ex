defmodule Boom.Presence do
  use Phoenix.Presence,
    otp_app: :boomgrid,
    pubsub_server: Boom.PubSub
end
