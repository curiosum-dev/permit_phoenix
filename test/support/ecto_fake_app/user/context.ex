defmodule Permit.EctoFakeApp.User.Context do
  @moduledoc false
  alias Permit.EctoFakeApp.Repo
  alias Permit.EctoFakeApp.User

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
