defmodule Permit.EctoFakeApp.Authorization do
  alias Permit.EctoFakeApp.{Permissions, Repo}

  use Permit.Ecto,
    permissions_module: Permissions,
    repo: Repo
end
