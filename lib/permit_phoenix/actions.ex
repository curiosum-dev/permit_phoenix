defmodule Permit.Phoenix.Actions do
  @moduledoc """
  Provides actions from a Phoenix router module.

  Example:

      defmodule MyApp.Router do
        # ...

        get("/items/:id", MyApp.ItemController, :view)
      end

      defmodule MyApp.Actions do
        use Permit.Actions

        # Merge the actions from the router into the default grouping schema.
        def grouping_schema do
          Permit.Phoenix.Actions.Defaults.grouping_schema()
          |> Permit.Phoenix.Actions.merge_from_router(MyApp.Router)
        end
      end

      defmodule MyApp.Permissions do
        # Use the actions module to define permissions.
        use Permit.Permissions, actions_module: MyApp.Actions

        def can(:admin = _role) do
          permit()
          |> all(Item)
        end

        # The `view` action is automatically added to the grouping schema
        # and hence available as a `view/2`function when defining permissions.
        def can(:owner = _role) do
          permit()
          |> view(Item)
          |> all(Item, fn user, item -> item.owner_id == user.id end)
        end

      end
  """

  def merge_from_router(grouping_schema, router_module) do
    actions_from_router(router_module)
    |> Enum.reduce(grouping_schema, fn action, acc ->
      if !Map.has_key?(acc, action), do: Map.put(acc, action, []), else: acc
    end)
  end

  defp actions_from_router(router_module) do
    router_module.__routes__()
    |> Stream.filter(fn route ->
      is_atom(route.plug_opts) and is_atom(route.plug) and Code.ensure_loaded?(route.plug) and
        function_exported?(route.plug, route.plug_opts, 2)
    end)
    |> Stream.map(fn route -> route.plug_opts end)
    |> Enum.uniq()
  end
end
