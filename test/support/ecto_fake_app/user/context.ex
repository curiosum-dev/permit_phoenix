defmodule Permit.EctoFakeApp.User.Context do
  alias Permit.EctoFakeApp.User
  alias Permit.EctoFakeApp.Repo

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
