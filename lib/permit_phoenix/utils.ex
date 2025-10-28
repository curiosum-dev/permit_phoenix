defmodule Permit.Phoenix.Utils do
  @moduledoc false

  def permit_ecto_available? do
    Mix.Project.config()[:deps]
    |> Enum.any?(fn
      {:permit_ecto, _} -> true
      {:permit_ecto, _, _} -> true
      _ -> false
    end)
  end
end
