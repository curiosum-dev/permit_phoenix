defmodule Permit.EctoFakeApp.Repo do
  use Ecto.Repo,
    otp_app: :permit_phoenix,
    adapter: Ecto.Adapters.Postgres

  alias Permit.EctoFakeApp.{User, Item, Repo}

  def seed_data! do
    users = [
      %User{id: 1} |> Repo.insert!(),
      %User{id: 2} |> Repo.insert!(),
      %User{id: 3} |> Repo.insert!()
    ]

    items = [
      %Item{id: 1, owner_id: 1, permission_level: 1} |> Repo.insert!(),
      %Item{id: 2, owner_id: 2, permission_level: 2, thread_name: "dmt"} |> Repo.insert!(),
      %Item{id: 3, owner_id: 3, permission_level: 3} |> Repo.insert!()
    ]

    %{users: users, items: items}
  end
end
