defmodule Permit.NonEctoFakeApp.SeedData do
  @moduledoc false
  alias Permit.NonEctoFakeApp.User
  alias Permit.NonEctoFakeApp.Item

  @users [
    %User{id: 1},
    %User{id: 2},
    %User{id: 3}
  ]

  @items [
    %Item{id: 1, owner_id: 1, permission_level: 1},
    %Item{id: 2, owner_id: 2, permission_level: 2, thread_name: "dmt"},
    %Item{id: 3, owner_id: 3, permission_level: 3}
  ]

  def users, do: @users
  def items, do: @items
end
