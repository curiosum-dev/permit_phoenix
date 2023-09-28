defmodule Permit.NonEctoFakeApp.Authorization do
  @moduledoc false
  alias Permit.NonEctoFakeApp.Permissions

  use Permit, permissions_module: Permissions
end
