defmodule Permit.EctoFakeApp.Actions do
  @moduledoc false
  use Permit.Actions

  def grouping_schema do
    Permit.Phoenix.Actions.Defaults.grouping_schema()
    |> Permit.Phoenix.Actions.merge_from_router(Permit.EctoFakeApp.Router)
  end
end
