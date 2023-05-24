ExUnit.start()
Application.ensure_all_started(:phoenix_live_view)

Application.put_env(
  :ecto,
  Permit.EctoFakeApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL", "ecto://localhost/ecto_network_test"),
  pool: Ecto.Adapters.SQL.Sandbox
)

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Permit.EctoFakeApp.Repo, :temporary)

# _ = Ecto.Adapters.Postgres.storage_down(Permit.NonEctoFakeApp.Repo.config())
# :ok = Ecto.Adapters.Postgres.storage_up(Permit.NonEctoFakeApp.Repo.config())

{:ok, _pid} = Permit.EctoFakeApp.Repo.start_link()

# Code.require_file("ecto_migration.exs", __DIR__)

# :ok = Ecto.Migrator.up(Permit.NonEctoFakeApp.Repo, 0, Ecto.Integration.Migration, log: false)
Process.flag(:trap_exit, true)
