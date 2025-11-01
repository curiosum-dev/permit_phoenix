defmodule Permit.Phoenix.Decorators.LiveView do
  @moduledoc false

  def __on_definition__(env, _kind, :handle_event, args, _guards, _body) do
    event_name = args |> List.first()
    attribute_value = Module.get_last_attribute(env.module, :permit_action, nil)

    # event_name must be a string - this means the event handler is defined
    # using pattern matching; otherwise, we cannot infer the event name from the
    # function body.

    cond do
      is_binary(event_name) and not is_nil(attribute_value) ->
        prior_value = Module.get_attribute(env.module, :__event_mapping__, %{})

        Module.put_attribute(
          env.module,
          :__event_mapping__,
          Map.put(prior_value, event_name, attribute_value)
        )

        # delete the permit_action attribute to avoid mapping different event names
        # to the same action.
        Module.delete_attribute(env.module, :permit_action)

      not is_binary(event_name) and not is_nil(attribute_value) ->
        # handle_event is not defined using pattern matching, so we cannot infer the event name from the
        # function body.
        # In this case, the user will have to implement event_mapping/0.

        msg = """
        @permit_action module attribute cannot be used with handle_event/3 clauses that do not pattern match directly on the event name.

        To handle events covered by this clause, please implement event_mapping/0 to map event names (strings) to Permit actions (atoms), for example:

          def event_mapping do
            %{
              "store" => :create,
              "patch" => :update
            }
          end

        Note that, in the presence of other event handlers that pattern match on the event name, mappings defined using @permit_action take precedence over mappings defined in event_mapping/0.
        """

        raise ArgumentError, msg

      true ->
        :ok
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok
end
