if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter.Test) do
  defmodule Mix.Tasks.PermitPhoenix.InstallTest do
    use ExUnit.Case

    import Igniter.Test

  defp project_with_web_module(opts \\ []) do
    app_name = Keyword.get(opts, :app_name, :test)

    test_project(
      app_name: app_name,
      files: %{
        "lib/test_web.ex" => """
        defmodule TestWeb do
          def live_view do
            quote do
              use Phoenix.LiveView

              unquote(html_helpers())
            end
          end

          def controller do
            quote do
              use Phoenix.Controller, formats: [:html, :json]
            end
          end

          defp html_helpers do
            quote do
              import Phoenix.HTML
            end
          end

          defmacro __using__(which) when is_atom(which) do
            apply(__MODULE__, which, [])
          end
        end
        """
      }
    )
  end

  describe "permit_phoenix.install" do
    test "creates actions module" do
      project_with_web_module()
      |> Igniter.compose_task("permit_phoenix.install", [])
      |> assert_creates("lib/test/authorization/actions.ex")
    end

    test "actions module uses Permit.Phoenix.Actions with router" do
      igniter =
        project_with_web_module()
        |> Igniter.compose_task("permit_phoenix.install", [])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/authorization/actions.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Permit.Phoenix.Actions, router: TestWeb.Router"
    end

    test "uses custom actions module name" do
      project_with_web_module()
      |> Igniter.compose_task("permit_phoenix.install", [
        "--actions-module",
        "Test.Auth.Actions"
      ])
      |> assert_creates("lib/test/auth/actions.ex")
    end

    test "uses custom router" do
      igniter =
        project_with_web_module()
        |> Igniter.compose_task("permit_phoenix.install", [
          "--router",
          "TestWeb.CustomRouter"
        ])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/authorization/actions.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "router: TestWeb.CustomRouter"
    end

    test "patches web module's live_view function" do
      igniter =
        project_with_web_module()
        |> Igniter.compose_task("permit_phoenix.install", [])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Permit.Phoenix.LiveView, authorization_module: Test.Authorization"
    end

    test "does not duplicate use Permit.Phoenix.LiveView if already present" do
      project =
        test_project(
          files: %{
            "lib/test_web.ex" => """
            defmodule TestWeb do
              def live_view do
                quote do
                  use Phoenix.LiveView
                  use Permit.Phoenix.LiveView, authorization_module: Test.Authorization
                end
              end

              defmacro __using__(which) when is_atom(which) do
                apply(__MODULE__, which, [])
              end
            end
            """
          }
        )

      igniter =
        project
        |> Igniter.compose_task("permit_phoenix.install", [])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      # Should appear exactly once
      matches = Regex.scan(~r/use Permit\.Phoenix\.LiveView/, content)
      assert length(matches) == 1
    end
  end
  end
end
