defmodule Permit.NonEctoFakeApp.Item.Context do
  @moduledoc false
  alias Permit.NonEctoFakeApp.Item

  @item1 %Item{id: 1, owner_id: 1, permission_level: 1}
  @item2 %Item{id: 2, owner_id: 2, permission_level: 2, thread_name: "dmt"}
  @item3 %Item{id: 3, owner_id: 3, permission_level: 3}

  def get_item("1"), do: @item1
  def get_item(1), do: @item1
  def get_item("2"), do: @item2
  def get_item(2), do: @item2
  def get_item("3"), do: @item3
  def get_item(3), do: @item3
  def get_item(_), do: nil

  def list_items do
    [@item1, @item2, @item3]
  end

  def create_item(attrs \\ %{}) do
    struct(Item, attrs)
  end
end
