defmodule Permit.NonEctoFakeApp.User.Context do
  alias Permit.NonEctoFakeApp.User

  def create_user(attrs \\ %{}) do
    struct(User, attrs)
  end

  def list_users do
    [
      %User{id: 1},
      %User{id: 2},
      %User{id: 3}
    ]
  end
end
