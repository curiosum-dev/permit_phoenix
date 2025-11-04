defmodule Permit.EctoFakeApp.Scope do
  @moduledoc false
  alias Permit.EctoFakeApp.User

  defstruct user: nil

  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
