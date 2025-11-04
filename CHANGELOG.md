# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Support for Phoenix Scopes integration in LiveViews (#33)

  LiveViews can now integrate with [Phoenix Scopes](https://hexdocs.pm/phoenix/scopes.html) (available in Phoenix 1.8+) for authorization. When enabled via the `use_scope?/0` callback, the LiveView will use `:current_scope` instead of `:current_user` for the subject assign. This is particularly useful for multi-tenant applications or when additional context beyond the user is needed. Example:

  ```elixir
  defmodule MyAppWeb.ArticleLive.Index do
    use Permit.Phoenix.LiveView,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article

    # Enable scope-based authorization
    @impl true
    def use_scope?, do: true

    @impl true
    def fetch_subject(_socket, session) do
      # Return a scope struct instead of just a user
      user_token = session["user_token"]
      user = user_token && MyApp.Accounts.get_user_by_session_token(user_token)
      MyApp.Accounts.Scope.for_user(user)
    end
  end
  ```

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
