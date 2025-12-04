defmodule Permit.EctoFakeApp.Repo do
  use Ecto.Repo,
    otp_app: :permit_phoenix,
    adapter: Ecto.Adapters.Postgres

  alias Permit.EctoFakeApp.Repo
  alias Permit.EctoFakeApp.SeedData

  def seed_data! do
    users = SeedData.users() |> Enum.map(&Repo.insert!(&1))
    items = SeedData.items() |> Enum.map(&Repo.insert!(&1))
    %{users: users, items: items}
  end
end
