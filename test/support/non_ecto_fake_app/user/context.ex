defmodule Permit.NonEctoFakeApp.User.Context do
  alias Permit.NonEctoFakeApp.User

  def create_user(attrs \\ %{}) do
    struct(User, attrs)
  end
end
