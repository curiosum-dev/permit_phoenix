defmodule Permit.Phoenix.CommonOpts do
  # This module will contain common code for options used across both the Plug and LiveView modules.
  # Private API, not intended for public use.
  @moduledoc false

  @doc false
  def skip_preload(opts) do
    cond do
      # skip_preload option takes precedence
      is_list(opts[:skip_preload]) ->
        opts[:skip_preload]

      # deprecated: if preload_actions is set, emit warning and convert to skip_preload
      is_list(opts[:preload_actions]) ->
        IO.warn(
          "The :preload_actions option is deprecated. Use :skip_preload instead. " <>
            "Actions not in skip_preload will automatically preload records.",
          Macro.Env.stacktrace(__ENV__)
        )

        # Can't reliably convert preload_actions to skip_preload, so we return default
        [:create, :new]

      # default
      true ->
        [:create, :new]
    end
  end
end
