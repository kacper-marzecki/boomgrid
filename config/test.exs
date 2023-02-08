import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :boomgrid, BoomWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6RrQ7ns/wrp+MpSNiaR6UtfV3MMZMSIi9IfU6eKDVRy/qFg9zzWjZv9NXq51aosB",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
