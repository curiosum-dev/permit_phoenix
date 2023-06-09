defmodule Permit.NonEctoFakeApp.Permissions do
  use Permit.RuleSyntax, actions_module: Permit.Phoenix.Actions

  alias Permit.NonEctoFakeApp.Item
  alias Permit.NonEctoFakeApp.User

  def can(:admin = role) do
    grant(role)
    |> all(Item)
  end

  def can(:owner = role) do
    grant(role)
    |> all(Item, fn user, item -> item.owner_id == user.id end)
  end

  def can(:inspector = role) do
    grant(role)
    |> read(Item)
  end

  def can(%{role: :moderator, level: 1} = role) do
    grant(role)
    |> all(Item, permission_level: {:<=, 1})
  end

  def can(%{role: :moderator, level: 2} = role) do
    grant(role)
    |> all(Item, permission_level: {{:not, :>}, 2})
  end

  def can(%{role: :thread_moderator, thread_name: thread} = role) do
    grant(role)
    |> all(Item, permission_level: {:<=, 3}, thread_name: {:ilike, thread})
  end

  def can(%User{id: id} = role) do
    grant(role)
    |> all(Item, owner_id: id)
  end

  def can(role), do: grant(role)
end
