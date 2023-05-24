defmodule Permit.RepoCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Permit.EctoFakeApp.Repo

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    end

    :ok
  end
end
