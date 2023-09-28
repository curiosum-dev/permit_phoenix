defmodule Permit.EctoFakeApp.Authorization do
  @moduledoc false
  alias Permit.EctoFakeApp.{Permissions, Repo}

  use Permit.Ecto,
    permissions_module: Permissions,
    repo: Repo
end
