defmodule Permit.EctoFakeApp.Permissions do
  @moduledoc false
  use Permit.Ecto.Permissions, actions_module: Permit.Phoenix.Actions

  alias Permit.EctoFakeApp.Item
  alias Permit.EctoFakeApp.User

  def can(:admin = _role) do
    permit()
    |> all(Item)
    |> all(User)
  end

  def can(:owner = _role) do
    permit()
    |> all(Item, [user, item], owner_id: user.id)
    |> all(User)
  end

  def can(:function_owner = _role) do
    permit()
    |> all(Item, fn user, item -> item.owner_id == user.id end)
  end

  def can(:inspector = _role) do
    permit()
    |> read(Item)
    |> read(User)
  end

  def can(%{role: :moderator, level: 1} = _role) do
    permit()
    |> all(Item, permission_level: {:<=, 1})
    |> all(User)
  end

  def can(%{role: :moderator, level: 2} = _role) do
    permit()
    |> all(Item, permission_level: {{:not, :>}, 2})
    |> all(User)
  end

  def can(%{role: :moderator, level: 3} = _role) do
    permit()
    |> read(Item)
    |> delete(User)
  end

  def can(%{role: :thread_moderator, thread_name: thread} = _role) do
    permit()
    |> all(Item, permission_level: {:<=, 3}, thread_name: {:ilike, thread})
    |> all(User)
  end

  def can(%User{id: id} = _role) do
    permit()
    |> all(Item, owner_id: id)
  end

  def can(_role), do: permit()
end
