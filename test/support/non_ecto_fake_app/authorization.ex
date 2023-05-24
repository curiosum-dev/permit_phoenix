defmodule Permit.NonEctoFakeApp.Authorization do
  alias Permit.NonEctoFakeApp.Permissions

  use Permit, permissions_module: Permissions
end
