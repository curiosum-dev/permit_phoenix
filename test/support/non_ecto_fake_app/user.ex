defmodule Permit.NonEctoFakeApp.User do
  @moduledoc false

  defstruct [:id, :permission_level, items: [], roles: []]

  defimpl Permit.SubjectMapping, for: Permit.NonEctoFakeApp.User do
    def subjects(user), do: user.roles
  end
end
