if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter.Test) do
  defmodule Mix.Tasks.Permit.Patch.ControllerTest do
    use ExUnit.Case

    import Igniter.Test

  defp project_with_controller(controller_code \\ nil) do
    code =
      controller_code ||
        """
        defmodule TestWeb.ItemController do
          use Phoenix.Controller, formats: [:html, :json]

          def index(conn, _params), do: text(conn, "index")
          def show(conn, _params), do: text(conn, "show")
        end
        """

    test_project(
      files: %{
        "lib/test_web/controllers/item_controller.ex" => code
      }
    )
  end

  describe "permit.patch.controller" do
    test "adds use Permit.Phoenix.Controller to a bare controller" do
      igniter =
        project_with_controller()
        |> Igniter.compose_task("permit.patch.controller", [
          "TestWeb.ItemController",
          "Test.Item"
        ])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/item_controller.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Permit.Phoenix.Controller"
      assert content =~ "authorization_module: Test.Authorization"
      assert content =~ "resource_module: Test.Item"
    end

    test "uses custom authorization module" do
      igniter =
        project_with_controller()
        |> Igniter.compose_task("permit.patch.controller", [
          "TestWeb.ItemController",
          "Test.Item",
          "--authorization-module",
          "Test.Auth"
        ])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/item_controller.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "authorization_module: Test.Auth"
    end

    test "adds resource_module callback when controller already has use Permit.Phoenix.Controller" do
      controller_code = """
      defmodule TestWeb.ItemController do
        use Phoenix.Controller, formats: [:html, :json]
        use Permit.Phoenix.Controller, authorization_module: Test.Authorization

        def index(conn, _params), do: text(conn, "index")
      end
      """

      igniter =
        project_with_controller(controller_code)
        |> Igniter.compose_task("permit.patch.controller", [
          "TestWeb.ItemController",
          "Test.Item"
        ])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/item_controller.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def resource_module, do: Test.Item"
    end

    test "is idempotent - does not duplicate when resource_module already defined" do
      controller_code = """
      defmodule TestWeb.ItemController do
        use Phoenix.Controller, formats: [:html, :json]

        use Permit.Phoenix.Controller,
          authorization_module: Test.Authorization,
          resource_module: Test.Item

        def index(conn, _params), do: text(conn, "index")
      end
      """

      igniter =
        project_with_controller(controller_code)
        |> Igniter.compose_task("permit.patch.controller", [
          "TestWeb.ItemController",
          "Test.Item"
        ])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/item_controller.ex")
      content = Rewrite.Source.get(source, :content)

      # Should not have a def resource_module callback (it's already in use options)
      refute content =~ "def resource_module"
      # Should have exactly one use Permit.Phoenix.Controller
      matches = Regex.scan(~r/use Permit\.Phoenix\.Controller/, content)
      assert length(matches) == 1
    end
  end
  end
end
