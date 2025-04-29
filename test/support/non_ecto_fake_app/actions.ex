defmodule Permit.NonEctoFakeApp.Actions do
  @moduledoc false
  use Permit.Phoenix.Actions, router: Permit.NonEctoFakeApp.RouterUsingLoader
end
