import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

config :permit_phoenix,
  ecto_repos: [Permit.EctoFakeApp.Repo]

config :permit_phoenix, Permit.EctoFakeApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "permit_phoenix_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Print only warnings and errors during test
config :logger, level: :warning

ExUnit.start()

# # This cleans up the test database and loads the schema
# Mix.Task.run("ecto.drop")
# Mix.Task.run("ecto.create")
# Mix.Task.run("ecto.load")

# {:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Permit.EctoFakeApp.Repo, :temporary)

# _ = Ecto.Adapters.Postgres.storage_down(Permit.EctoFakeApp.Repo.config())
# :ok = Ecto.Adapters.Postgres.storage_up(Permit.EctoFakeApp.Repo.config())

# Start a process ONLY for our test run.
# {:ok, _pid} = Permit.EctoFakeApp.Repo.start_link

# Code.require_file("ecto_migration.exs", __DIR__)

# :ok = Ecto.Migrator.up(Permit.EctoFakeApp.Repo, 0, Ecto.Integration.Migration, log: false)
# Ecto.Adapters.SQL.Sandbox.mode(Permit.EctoFakeApp.Repo, :manual)
