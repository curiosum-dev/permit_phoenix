defmodule Permit.NonEctoFakeApp.User do
  @moduledoc false

  defstruct [:id, :permission_level, items: [], roles: []]

  defimpl Permit.HasRoles, for: Permit.NonEctoFakeApp.User do
    def roles(user), do: user.roles
  end
end
