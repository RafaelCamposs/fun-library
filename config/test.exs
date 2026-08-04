import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :fun_library, FunLibrary.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "my_secure_password_123",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: "fun_library_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fun_library, FunLibraryWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "pv1OEtnj8RNnYirw7OouGAUK4LQ22TGnMial79wDKd1GEJOQBzc5lLvUvDfXSq8V",
  server: false

# In test we don't send emails
config :fun_library, FunLibrary.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
