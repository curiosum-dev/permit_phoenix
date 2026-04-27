defmodule Permit.Phoenix.ActionPlurality.ActionsTest do
  use ExUnit.Case, async: true

  alias Permit.EctoFakeApp.Router

  describe "singular_actions/2" do
    test ":index stays plural even with trailing non-id params" do
      refute :index in Permit.Phoenix.Actions.singular_actions(Router)
    end

    test ":show with trailing :slug param is singular" do
      assert :show in Permit.Phoenix.Actions.singular_actions(Router)
    end

    test "custom action with trailing non-id param is inferred singular" do
      assert :custom_view in Permit.Phoenix.Actions.singular_actions(Router)
    end

    test "user-supplied plural actions are excluded from router-based promotion" do
      refute :feed in Permit.Phoenix.Actions.singular_actions(Router, [:feed])
    end

    test "without extra_plural, :feed would be inferred singular" do
      assert :feed in Permit.Phoenix.Actions.singular_actions(Router)
    end

    test "defaults to @default_singular_actions when no router" do
      actions = Permit.Phoenix.Actions.singular_actions(nil)
      assert :show in actions
      assert :edit in actions
      refute :index in actions
    end
  end
end
