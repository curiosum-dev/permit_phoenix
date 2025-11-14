# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- [Breaking] Support for Phoenix Scopes integration in LiveViews & controllers (#33)

  LiveViews can now integrate with [Phoenix Scopes](https://hexdocs.pm/phoenix/scopes.html) (available in Phoenix 1.8+) for authorization. When enabled via the `use_scope?/0` callback, the LiveView will use `:current_scope` instead of `:current_user` for the subject assign. This is particularly useful for multi-tenant applications or when additional context beyond the user is needed. Example:

  To bootstrap it in the current version of Phoenix (>= 1.8) and LiveView, this is really all you need to do now:
  ```elixir
  defmodule MyAppWeb.ArticleLive.Index do
    # Put it in the controller, or the `MyAppWeb` module's `live_view` function
    use Permit.Phoenix.LiveView,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article

    # If you're using Phoenix >=1.8's `mix phx.gen.auth` and only need to authorize against,
    # the current user (`@current_scope.user`), that's all!
  end
  ```

  Options can be set using `use` options or callback implementations. You can switch to authorizing against `@current_user`, using a different scope key (or the entire scope) as the subject, or fetch the subject from the session.
  See the README for a full configuration guidance.
  ```

  In Controllers, likewise, you can use the :use_scope? option or callback to enable or disable scope-based subject assignment.

### Changed

- [Breaking] Permit.Phoenix.LiveView no longer needs to have the `fetch_subject/2` callback implemented, and its result is no longer assigned to the `:current_user` assign - so that Permit no longer interferes with your assigns. This was a leftover from before `mix phx.gen.auth` became the de facto standard.
- [Breaking] Change default behaviour of `handle_unauthorized/2` in LiveView (#39)

  Prior to this version, by default, authorization errors in LiveView would always lead to a flash being displayed and a `push_navigate` to the configured `:fallback_path` (`/` by default). This wasn't practical as it worked this way regardless of whether authorization failed in mounting, navigation (`handle_params`) or event processing (`handle_event`), which meant that almost any practical usage required writing a custom `handle_unauthorized` handler.

  This is now changed:
  - `put_flash(:error, socket.view.unauthorized_message(action, socket)` is always done,
  - `push_navigate(socket, to: socket.view.fallback_path(action, socket))` is done if the LiveView is in the mounting phase,
  - `fallback_path` defaults to the current `_live_referer` path if available, otherwise it is `/`. This means that if using the [link](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#link/1) component with `:navigate` option within the current session, we will still be able to navigate back to the currently displayed page, even though it will go through the mounting phase.

## [0.3.1]

### Fixed

- Fix method of checking for Permit.Ecto existence (#34). Now it should be working correctly both when using hex and path dependencies.
- Add missing `defoverridable event_mapping: 0` to `Permit.Phoenix.LiveView` to allow overriding the `event_mapping` function in child modules.

## [0.3.0]

### Added

- Support for Phoenix LiveView 1.x (#24)

  Dependency specs have been updated to allow LiveView 1.x usage. GitHub Actions matrix has been updated to include Elixir >= 1.14, OTP >= 26, Phoenix >= 1.6 and LiveView >= 0.20 (going forward, < 1.x will be dropped).

- Support for automatic inference of action names from controller and LiveView routes (#28).

  Thanks to this, actions corresponding to controller actions and `:live_action` no longer have to be defined explicitly in the actions module. Example:

  ```elixir
  defmodule MyApp.Actions do
    # Merge the actions from the router into the default grouping schema.
    use Permit.Phoenix.Actions, router: MyAppWeb.Router
  end
  ```

- Add option to use streams instead of assigns (d6e2d2d).

  The `use_stream?/1` callback (and `:use_stream?` option key) was added to `Permit.Phoenix.LiveView`, defaulting to `false`. When set to `true`, it directs Permit.Phoenix to insert the loaded-and-authorized resources as the `:loaded_resources` stream, as opposed to an assign key, if dealing with a plural (e.g. `:index`) action. Example:

  ```elixir
  defmodule MyApp.SomethingLive do
    use Permit.Phoenix.LiveView,
      authorization_module: MyApp.Authorization,
      resource_module: Something,
      use_stream?: true

    # Alternatively use callback with socket argument
    @impl true
    def use_stream?(%{assigns: %{live_action: _}} = _socket) do
      # Logic dependent on socket, e.g. taken from :live_action
      true
    end

    @impl true
    def handle_params(_params, _url, socket) do
      # The :loaded_resources stream is accessible
      {:noreply, socket}
    end
  end
  ```

### Fixed

- Missing alias to Types in AuthorizeHook
- `Permit.Ecto`-related callbacks not correctly defined (#23)
- Improved detection of Permit.Ecto presence using mix lock data
- Fix static checks, dialyzer indications, and Credo warnings

### Changed

- [Breaking] Drop LiveView < 0.20 support
- [Breaking] Skip load-and-authorize in handle_params after mount
- Updated CI and testing configuration
- Updated development dependencies to fix deprecation warnings

## [0.2.0]

### Added

- Support for customizing responses when records are not found with `handle_not_found` callback
- Custom RecordNotFound exception for better error handling
- Authorization for handle_event in LiveView
- Support for using loader with Permit.Ecto.Resolver
- Added event_mapping callback for LiveView

### Changed

- Updated dependencies to latest versions of permit and permit_ecto
- Renamed attach_params_hook to attach_hooks for better clarity

### Fixed

- Allow specifying fallback_path and unauthorized_message as functions
- Tests and fixes for fallback_path and unauthorized_message as functions
- Fixed missing :update and :delete actions in singular and preloadable actions
- Fixed checks for presence of Permit.Ecto
- Various compilation warnings and code style improvements

## [0.1.0]

### Added

- Initial stable release
- Phoenix Framework integration for Permit authorization library
- LiveView integration for authorization
- Controller integration with authorization plugs
- Support for preloading resources based on permissions
- Configurable authorization callbacks
- Documentation and examples in README

### Changed

- Upgraded dependencies to enforce usage of bugfixed versions
- Documentation improvements and fixes to Credo indications
- Code cleanup and test coverage improvements

### Fixed

- Fixed various bugs identified during initial testing
- Removed assigns when changing action in LiveView
