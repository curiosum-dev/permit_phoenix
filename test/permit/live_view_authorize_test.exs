defmodule Permit.LiveViewAuthorizeTest do
  use ExUnit.Case, async: true

  alias Permit.Phoenix.LiveView
  alias Permit.NonEctoFakeApp.{Authorization, Item, User}

  # Mock socket structure
  defp mock_socket(assigns, private) do
    %Phoenix.LiveView.Socket{
      view: __MODULE__.TestLiveView,
      assigns: assigns,
      private: Map.merge(%{permit_subject: %User{id: 1, roles: ["admin"]}}, private)
    }
  end

  # Test LiveView module for authorize! tests
  defmodule TestLiveView do
    def authorization_module, do: Authorization

    def handle_unauthorized(_action, socket) do
      {:halt, Map.put(socket, :assigns, Map.put(socket.assigns, :unauthorized_called, true))}
    end

    def handle_not_found(socket) do
      {:halt, Map.put(socket, :assigns, Map.put(socket.assigns, :not_found_called, true))}
    end
  end

  describe "authorize!/4" do
    test "executes function when resource exists and user is authorized" do
      # Admin user should be authorized for all actions
      socket = mock_socket(%{}, %{permit_subject: %User{id: 1, roles: [:admin]}})
      # Different owner, but admin should have access
      resource = %Item{id: 1, owner_id: 2}

      # Mock function that sets a flag
      test_fun = fn ->
        send(self(), :function_executed)
        :ok
      end

      result = LiveView.authorize!(socket, :read, resource, test_fun)

      assert {:noreply, %Phoenix.LiveView.Socket{}} = result
      assert_received :function_executed
    end

    test "calls handle_not_found when resource is nil" do
      socket = mock_socket(%{}, %{})

      test_fun = fn ->
        send(self(), :function_executed)
        :ok
      end

      result = LiveView.authorize!(socket, :read, nil, test_fun)

      assert {:noreply, returned_socket} = result
      assert returned_socket.assigns.not_found_called == true
      refute_received :function_executed
    end

    test "calls handle_unauthorized when user lacks permission" do
      # Create socket with user who doesn't have permission (inspector can only read)
      socket = mock_socket(%{}, %{permit_subject: %User{id: 2, roles: [:inspector]}})
      # Resource owned by user 1, not user 2
      resource = %Item{id: 1, owner_id: 1}

      test_fun = fn ->
        send(self(), :function_executed)
        :ok
      end

      result = LiveView.authorize!(socket, :update, resource, test_fun)

      assert {:noreply, returned_socket} = result
      assert returned_socket.assigns.unauthorized_called == true
      refute_received :function_executed
    end

    test "raises error when permit_subject is nil" do
      socket = mock_socket(%{}, %{permit_subject: nil})
      resource = %Item{id: 1, owner_id: 1}

      test_fun = fn ->
        send(self(), :function_executed)
        :ok
      end

      # The authorization system raises an error when user is nil
      assert_raise RuntimeError, "Unable to create permit authorization for nil role/user", fn ->
        LiveView.authorize!(socket, :read, resource, test_fun)
      end

      refute_received :function_executed
    end

    test "preserves socket state when executing function" do
      socket =
        mock_socket(%{test_assign: "original_value"}, %{
          permit_subject: %User{id: 1, roles: [:admin]}
        })

      resource = %Item{id: 1, owner_id: 1}

      test_fun = fn ->
        # Function doesn't modify socket directly
        :ok
      end

      result = LiveView.authorize!(socket, :read, resource, test_fun)

      assert {:noreply, returned_socket} = result
      assert returned_socket.assigns.test_assign == "original_value"
    end
  end
end
