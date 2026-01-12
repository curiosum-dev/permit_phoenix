<div align="center">
  <img src="https://github.com/user-attachments/assets/f0352656-397d-4d90-999a-d3adbae1095f">

  <h1>Permit.Phoenix</h1>
  <p>
    <strong>
      Phoenix Framework and LiveView integration for Permit - Authorization made simple for controllers and
      live views.
    </strong>
  </p>

[![Contact Us](https://img.shields.io/badge/Contact%20Us-%23F36D2E?style=for-the-badge&logo=maildotru&logoColor=white&labelColor=F36D2E)](https://curiosum.com/contact)
[![Visit Curiosum](https://img.shields.io/badge/Visit%20Curiosum-%236819E6?style=for-the-badge&logo=elixir&logoColor=white&labelColor=6819E6)](https://curiosum.com/services/elixir-software-development)
[![License: MIT](https://img.shields.io/badge/License-MIT-1D0642?style=for-the-badge&logo=open-source-initiative&logoColor=white&labelColor=1D0642)]()

</div>

<br/>

## Purpose and usage

Permit.Phoenix provides seamless authorization integration for Phoenix Framework applications, enabling consistent
permission checking across controllers and LiveViews without code duplication.

Key features:

- **Automatic authorization** - Plug-based controllers and LiveViews authorize actions automatically
- **Resource preloading** - Automatically load and scope single database records and lists based on user permissions
- **LiveView 1.0+ support** - Optional integration with streams and modern LiveView features
- **Flexible error handling** - Customizable unauthorized and not-found behaviors
- **Router integration** - Automatic action mapping from Phoenix routes
- **Event authorization** - Authorize LiveView events with custom mapping

[![Hex version badge](https://img.shields.io/hexpm/v/permit_phoenix.svg)](https://hex.pm/packages/permit_phoenix)
[![Actions Status](https://github.com/curiosum-dev/permit_phoenix/actions/workflows/elixir.yml/badge.svg)](https://github.com/curiosum-dev/permit_phoenix/actions)
[![Code coverage badge](https://img.shields.io/codecov/c/github/curiosum-dev/permit_phoenix/master.svg)](https://codecov.io/gh/curiosum-dev/permit_phoenix/branch/master)
[![License badge](https://img.shields.io/hexpm/l/permit_phoenix.svg)](https://github.com/curiosum-dev/permit_phoenix/blob/master/LICENSE.md)

## Installation

The package can be installed by adding `permit_phoenix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:permit, "~> 0.3.2"},          # Core authorization library
    {:permit_phoenix, "~> 0.4.0"},  # Phoenix & LiveView integration
    {:permit_ecto, "~> 0.2.4"}      # Optional: for database integration
  ]
end
```

For GraphQL support, also add `:permit_absinthe`.

## Quick start

Assumes Phoenix 1.8+ and authentication generated with `mix phx.gen.auth`, with scopes used by default (i.e.
current user is available as `@current_scope.user`).

1. Create your Actions module (`lib/my_app/actions.ex`):
    ```elixir
    defmodule MyApp.Actions do
      # Permission-defining functions will be generated based on action names from the router.
      use Permit.Phoenix.Actions, router: MyAppWeb.Router
    end
    ```

2. Create your Permissions module (`lib/my_app/permissions.ex`):
    ```elixir
    defmodule MyApp.Permissions do
      use Permit.Ecto.Permissions, actions_module: MyApp.Actions

      def can(%MyApp.Accounts.Scope{user: %{id: user_id}}) do
        permit()
        |> all(MyApp.Article, author_id: user_id)
        |> read(MyApp.Article)
      end

      def can(_), do: permit()
    end
    ```

3. Create your Authorization module (`lib/my_app/authorization.ex`):
    ```elixir
    defmodule MyApp.Authorization do
      use Permit.Ecto,
        permissions_module: MyApp.Permissions,
        repo: MyApp.Repo
    end
    ```

4. Configure your web module (`lib/my_app_web/web.ex`):
    ```elixir
    # In controller/0:
    use Permit.Phoenix.Controller,
      authorization_module: MyApp.Authorization

    # In live_view/0:
    use Permit.Phoenix.LiveView,
      authorization_module: MyApp.Authorization
    ```

5. Update your router for LiveView integration (`lib/my_app_web/router.ex`):
    ```elixir
    live_session :require_authenticated_user,
      on_mount: [
        {MyAppWeb.UserAuth, :ensure_authenticated},
        Permit.Phoenix.LiveView.AuthorizeHook  # Add this line
      ] do
      # your routes
    end
    ```

## How it works

- [`Permit`](https://hexdocs.pm/permit) provides the permission definition syntax
- [`Permit.Ecto`](https://hexdocs.pm/permit_ecto) is optional, but - if present - it constructs queries to look up
accessible records from a database, based on defined permissions
- `Permit.Phoenix` plugs into controllers and live views in order to automatically preload records and check
authorization permissions to perform actions.

Requires `:permit` and `:permit_phoenix` packages, with optional `:permit_ecto` for database integration.

## Configuration

While in basic Permit all actions must be defined in a module implementing the `Permit.Actions` behaviour, in the
`grouping_schema/0` callback implementation, in Phoenix it is potentially inconvenient - adding a new controller
action name would require adding it to the `grouping_schema/0` implementation every single time.

For this reason, **Permit.Phoenix provides the `Permit.Phoenix.Actions` module**, building upon the standard way
of defining action names with `Permit.Actions` and additionally enabling you to automatically define actions based
on controller and LiveView actions defined in the router.

```elixir
defmodule MyApp.Authorization do
  use Permit.Ecto,
    permissions_module: MyApp.Permissions,
    repo: MyApp.Repo
end

defmodule MyApp.Actions do
  # Merge the actions from the router into the default grouping schema.
  use Permit.Phoenix.Actions, router: MyAppWeb.Router
end

defmodule MyAppWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  # :view and :watch will get imported into `MyApp.Actions.grouping_schema/0`.
  # This way you won't have to add them manually.
  get("/items/:id/view", MyAppWeb.ItemController, :view)
  live("/items/:id/watch", MyAppWeb.ItemLive, :watch)
end

defmodule MyApp.Permissions do
  @moduledoc false
  use Permit.Ecto.Permissions, actions_module: MyApp.Actions

  def can(%{id: user_id} = _user) do
    permit()
    |> create(MyApp.Item)
    |> view(MyApp.Item, owner_id: user_id)
    |> watch(MyApp.Item, owner_id: user_id)
  end

  def can(_user), do: permit()
end
```

The `view/3` and `watch/3` functions are shorthands to `permission_to/4` in which the first argument would've
been `:view` or `:watch`, respectively - they're generated based on the module implementing `grouping_schema/0`
callback from `Permit.Actions`.

## Controllers

All options of `Permit.Phoenix.Controller` can be provided as option keywords with `use Permit.Phoenix.Controller`
or as callback implementations. For example, defining a `handle_unauthorized: fn action, conn -> ... end` option
is equivalent to:

```elixir
@impl true
def handle_unauthorized(action, conn), do: ...
```

In practice, it depends on use case:

- when providing options for different actions, etc., consider using callback implementations
- if you want to provide values as literals instead of functions, consider using option keywords
- for global settings throughout controllers using `use MyAppWeb, :controller`, set globals as keywords, and
override in specific controllers using callback implementations.

Whenever `resolution_context` is referred to, it is typified by `Permit.Types.resolution_context`.

### One-off usage

```elixir
defmodule MyAppWeb.ArticleController do
  use Permit.Phoenix.Controller,
    # Mandatory options:
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article,

    # Additional available options:
    fallback_path: fn action, conn -> ... end,
    handle_unauthorized: fn action, conn -> ... end,
    fetch_subject: fn conn -> ... end,
    preload_actions: [:action1, :action2, ...],
    except: [:action3, :action4, ...],
    id_param_name: fn action, conn -> ... end,
    id_struct_field_name: fn action, conn -> ... end,

    # Non-Ecto only:
    loader: fn resolution_context -> ... end,

    # Ecto only:
    base_query: fn resolution_context -> ... end,
    finalize_query: fn query, resolution_context -> ... end

  def show(conn, params) do
    # If there is a MyApp.Article with ID == params[:id] that
    # matches the current user's permissions, it will be
    # available as the @loaded_resource assign.
    #
    # Otherwise, handle_unauthorized/2 is called, defaulting to
    # redirecting to `/`.
  end

  def index(conn, params) do
    # If the :index action is authorized for the user, the
    # @loaded_resources assign will contain all records accessible
    # by the current user per the app's permissions configuration.
    #
    # Pagination and other concerns can be configured with
    # the base_query/1 callback.
    #
    # Otherwise, handle_unauthorized/2 is called, defaulting to
    # redirecting to `/`.
  end
end
```

### Global usage with settings in specific controllers

```elixir
defmodule MyAppWeb do
  def controller do
    quote do
      # ...
      use Permit.Phoenix.Controller,
        authorization_module: MyApp.Authorization,
        # global options go here
    end
  end
end

defmodule MyAppWeb.ArticleController do
  use MyAppWeb, :controller

  @impl true
  def resource_module, do: MyApp.Article

  # etc., etc.
end
```

### Using without Ecto

If you're not using Ecto, you can provide a custom loader function:

```elixir
defmodule MyAppWeb.ArticleController do
  # Capture a function to be used as loader
  # (see Permit.Phoenix.Controller.loader/1 callback).
  use Permit.Phoenix.Controller,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article,
    loader: &MyApp.ArticleContext.load/1

  # Alternatively, loader function (adhering to the same callback signature)
  # can be defined directly in a controller.
  @impl true
  def loader(%{action: :index, params: params}) do
    MyApp.ArticleContext.list_articles(params)
  end

  def loader(%{action: action, params: %{"id" => id}})
    when action in [:show, :edit, :update, :delete] do
    MyApp.ArticleContext.get_article(id)
  end
end
```

### Advanced error handling

```elixir
defmodule MyAppWeb.ArticleController do
  use Permit.Phoenix.Controller,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  @impl true
  def handle_unauthorized(action, conn) do
    case get_format(conn) do
      "json" ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})
        |> halt()

      "html" ->
        conn
        |> put_flash(:error, "You don't have permission for this action")
        |> redirect(to: "/")
        |> halt()
    end
  end

  @impl true
  def handle_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_flash(:error, "Resource not found")
    |> redirect(to: "/")
    |> halt()
  end

  @impl true
  def unauthorized_message(action, conn) do
    "You cannot #{action} this article"
  end
end
```

## LiveView

To use Permit.Phoenix with LiveView, the provided hook module must be added to the `:on_mount` option of the
`live_session` in the router, then configure authorization in your app's LiveView modules.

### Router configuration

```elixir
defmodule MyAppWeb.Router do
  # ...

  scope "/", MyAppWeb do
    # ...

    # Configure using an :on_mount hook
    live_session :my_app_session, on_mount: [
      {MyAppWeb.UserAuth, :ensure_authenticated},
      Permit.Phoenix.LiveView.AuthorizeHook # Add after authentication
    ] do
      # The :live_action names provided here will be
      live "/live/articles", ArticleLive.Index, :index
      live "/live/articles/new", ArticleLive.Index, :new
      live "/live/articles/:id/edit", ArticleLive.Index, :edit

      live "/live/articles/:id", ArticleLive.Show, :show
      live "/live/articles/:id/show/edit", ArticleLive.Show, :edit
    end
  end
end
```

### LiveView configuration

Permit.Phoenix.LiveView performs authorization at three key points:

1. **During mount** - via the `on_mount: Permit.Phoenix.LiveView.AuthorizeHook`
2. **During live navigation** - when `handle_params/3` is called and `:live_action` changes
3. **During events** - when `handle_event/3` is called for events defined in `event_mapping/0`

In a similar way to configuring controllers, LiveViews can be configured with option keywords or callback
implementations, thus let's omit lengthy examples of both.

Most options are similar to controller options, with `socket` in place of `conn`.

```elixir
defmodule MyAppWeb.ArticleLive.Index do
  use MyAppWeb, :live_view

  use Permit.Phoenix.LiveView,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  @impl true
  def mount(_params, _session, socket) do
    # If the :index action is authorized, @loaded_resources assign
    # will contain the list of accessible resources (maybe empty).
    #
    # Pagination, etc. can be configured using base_query/1 callback.
  end

  @impl true
  def handle_params(params, _url, socket) do
    # If assigns[:live_action] has changed, authorization and preloading occurs.
    #
    # If authorized successfully, it is assigned into @loaded_resource or
    # @loaded_resources for singular and plural actions, respectively.
    #
    # If authorization fails, the default implementation of handle_unauthorized/2
    # does:
    #   {:halt, push_redirect(socket, to: "/")}
    # Alternatively you can implement a callback to do something different,
    # for instance you can do {:cont, ...} and assign something to the socket
    # to display a message.
  end
end
```

### Authorizing LiveView Events

You can also authorize Phoenix LiveView events:

```elixir
defmodule MyAppWeb.ArticleLive.Show do
  use Permit.Phoenix.LiveView,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  @impl true
  def handle_event("delete", params, socket) do
    # Event authorization happens automatically based on event_mapping
    {:noreply, socket}
  end

  # Customize event to action mapping: "delete" event will be authorized against
  # Permit rules for :delete action on MyApp.Article.
  @impl true
  def event_mapping do
    %{
      "delete" => :delete,
      "archive" => :update,
      "publish" => :create
    }
  end
end
```

### Using streams in LiveView

For better performance with large datasets, you can use streams instead of assigns:

```elixir
defmodule MyAppWeb.ArticleLive.Index do
  # Configure Permit.Phoenix.LiveView to use streams in plural actions
  # such as :index.
  use Permit.Phoenix.LiveView,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article,
    use_stream?: true

  # Alternatively, use a callback for conditional stream usage.
  #
  # You needn't set use_stream? to false with singular actions, e.g. :show, etc.
  # - in their case, even if set to true, normal assigns will be used.
  @impl true
  def use_stream?(%{assigns: %{live_action: :index}} = _socket), do: true
  def use_stream?(_socket), do: false

  @impl true
  def handle_params(_params, _url, socket) do
    # Resources are now available as the :loaded_resources stream if navigating
    # to a plural action.
    {:noreply, socket}
  end
end
```

### Handling authorization errors in LiveView

LiveView error handling in Permit.Phoenix covers both navigation-based authorization (via `:live_action`) and
event-based authorization. Understanding when to use `{:cont, socket}` vs `{:halt, socket}` and the role of
navigation is crucial for proper error handling.

**By default**, authorization errors result in displaying a flash message (customizable using the `:unauthorized_message`
option or callback). If needed (e.g. entering a route via a direct link from outside a LiveView session), the
`:fallback_path` option is configurable so it can be navigated to (defaulting to `/`).

Permit.Phoenix provides a useful `mounting?/1` function to help you determine the appropriate error handling response
- which may be different depending on whether the page is being rendered server-side, or it is dealing with in-place
navigation via `handle_params`.

```elixir
defmodule MyAppWeb.ArticleLive.Show do
  use Permit.Phoenix.LiveView,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  @impl true
  def handle_unauthorized(action, socket) do
    # Use mounting?/1 to determine the appropriate response
    if mounting?(socket) do
      # During mount - redirect is required for halt to work properly
      socket =
        socket
        |> put_flash(:error, "Access denied")
        |> push_navigate(to: ~p"/articles")

      {:halt, socket}  # Must redirect during mount
    else
      # During handle_params navigation - can stay on page
      socket =
        socket
        |> assign(:access_denied, true)
        |> put_flash(:error, "Access denied for this view")

      {:cont, socket}  # Can show inline error during navigation
    end
  end
end
```

## Subjects, current user, and Phoenix Scopes

Permit's `subject` is typically the current user, in other words, the actor that is performing the action; or any
data structure that represents the actor and contains all the information needed to verify its permissions against a
resource.

The subject is passed to the permission-defining functions in your `Permissions` module, so its fields can be
pattern matched on.

In some cases, you may need to authorize against a different structure.
- For purely role-based authorization, the subject would just be the current user's `:role` field.
- When Phoenix Scopes are used, and other scope-encapsulated data (e.g. the user's tenant organization) is needed,
the subject would be the entire scope struct.

This can be customized using options described below.

### Configuration with Phoenix Scopes

Permit.Phoenix LiveView and Controller integrations supports [Phoenix Scopes](https://hexdocs.pm/phoenix/scopes.html)
(available in Phoenix 1.8+), which are data structures that hold information about the current request or session
(current user, organization, permissions, etc.). Scopes are particularly useful for multi-tenant applications or
when you need to maintain more than just user information.

This is used by default in the current version of Phoenix (>= 1.8) and LiveView, and is recommended.

First, ensure your scope is defined (usually generated by `mix phx.gen.auth`):

```elixir
# lib/my_app/accounts/scope.ex
defmodule MyApp.Accounts.Scope do
  alias MyApp.Accounts.User

  defstruct user: nil

  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
```

Examples below are for LiveView, but configuration for controllers is identical - using `use` option keywords or
allback implementations.

Then, configure your LiveView to use scopes - in the current version of Phoenix (>= 1.8) and LiveView, this is
really all you need to do now:
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

For compatibility with projects created with Phoenix <1.8, or when using a custom configuration, you can disable
scope-based authorization and use the traditional approach:

```elixir
defmodule MyAppWeb do
  def live_view do
    quote do
      use Permit.Phoenix.LiveView,
        authorization_module: MyApp.Authorization,
        resource_module: MyApp.Article,
        scope_subject: :admin # Use the admin key as the subject by default
        use_scope?: false, # Switch to authorizing against @current_user
        fetch_subject: fn _socket, session -> ... end # Fetch the subject from the session
    end
  end
end
```
Then, you can override the options in a specific LiveView using callbacks - see traditional configuration example
below.

### Custom Scope-Subject Mapping

You can configure that the subject should be the entire scope struct, instead of just the user key, by setting
`scope_subject` to `scope` itself, or perhaps a different key in the scope, e.g. `:admin`.

```elixir
defmodule MyAppWeb.ArticleLive.Index do
  use MyAppWeb, :live_view

  # Use a different key (e.g. `@current_scope.admin`), or the entire scope as the
  # subject
  @impl true
  def scope_subject(scope), do: scope

  @impl true
  def mount(_params, _session, socket) do
    # socket.assigns.current_scope contains whatever is needed in the app's context
    {:ok, socket}
  end
end
```

If you've configured `scope_subject` as `scope` itself, inside the `can/1` predicates you'll have access to the
entire scope struct.

Update your permissions to work with scopes:

```elixir
defmodule MyApp.Permissions do
  use Permit.Ecto.Permissions, actions_module: MyApp.Actions

  # The subject passed will be the scope struct
  def can(%MyApp.Accounts.Scope{user: %{id: user_id}}) do
    permit()
    |> read(MyApp.Article, user_id: user_id)
    |> create(MyApp.Article)
  end

  def can(_scope), do: permit()
end
```

### Configuration without Phoenix Scopes (Traditional)

For applications not using Phoenix Scopes, continue using the traditional approach and use the
`fetch_subject/2` callback to fetch the subject from the session:

```elixir
defmodule MyAppWeb.ArticleLive.Index do
  use MyAppWeb, :live_view

  # For Phoenix projects bootstrapped below 1.8, disable scope-based authorization
  # (will take current user from the :current_user assign)
  @impl true
  def use_scope?, do: false

  # Optional - if you need to fetch the subject differently than by default (from
  # the :current_scope assign or the current_user assign)
  @impl true
  def fetch_subject(_socket, session) do
    # Fetch and return the current user directly
    user_token = session["user_token"]
    user_token && MyApp.Accounts.get_user_by_session_token(user_token)
  end

  @impl true
  def mount(_params, _session, socket) do
    # The user is available as socket.assigns.current_user
    {:ok, socket}
  end
end
```

## Actions: naming and grouping

Actions defined in the app's Actions module generate convenience functions in your permissions module to
grant authorization to them:
```elixir
defmodule MyApp.Actions do
  use Permit.Actions

  def grouping_schema do
    %{
      view: []
    }
  end
end

defmodule MyApp.Permissions do
  use Permit.Permissions, actions_module: MyApp.Actions

  def can(_user) do
    permit()
    |> view(MyApp.Item) # view/1 generated by grouping_schema/0
  end
end
```

Corresponding `action_name?/2` functions are generated for each action in the grouping schema in the
authorization module, so you can perform an authorization check.
```elixir
iex> MyApp.Authorization.can(%{id: 1}) |> MyApp.Authorization.view?(%MyApp.Item{id: 1})
true
```

### Action grouping

Thanks to default mapping defined in `Permit.Phoenix.Actions`, the default `:create`, `:read`, and `:update`
permissions are automatically extended to `:new` (for `:create`), `:index` and `:show` (for `:read`), and `:edit`
(for `:update`) - this is for convenience when using default Phoenix action names.

This is inspired by CanCanCan's default behaviour - Ruby on Rails practitioners may be familiar with it.

By default, `Permit.Phoenix.Actions` provides the following action mapping to implement this behaviour:

```elixir
%{
  new: [:create],
  index: [:read],
  show: [:read],
  edit: [:update],
  delete: []
}
```

Then, `:read` permission will also permit `:index` and `:show` - both in direct checks via your authorization
module, and in automatic load-and-authorize flow in LiveViews and controllers.

```elixir
def can(_user) do
  permit()
  |> read(MyApp.Item) # allows :index and :show
end

iex> MyApp.Authorization.can(%{id: 1}) |> MyApp.Authorization.read?(%MyApp.Item{id: 1})
true

iex> MyApp.Authorization.can(%{id: 1}) |> MyApp.Authorization.show?(%MyApp.Item{id: 1})
true

iex> MyApp.Authorization.can(%{id: 1}) |> MyApp.Authorization.index?(%MyApp.Item{id: 1})
true
```

### Actions from routes

For convenience, the `:router` option of `use Permit.Phoenix.Actions` allows taking action names from the router
 - it will include all controller action names and defined `:live_action` names for live routes.

```elixir
defmodule MyApp.Router do
  # ...

  get("/items/:id", MyApp.ItemController, :view)
end

defmodule MyApp.Actions do
  # Will include :view action in the grouping schema
  use Permit.Phoenix.Actions, router: MyApp.Router
end
```

## Ecosystem

Permit.Phoenix is part of the modular Permit ecosystem:

| Package                                                                | Version                                                                                                  | Description                                |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **[permit](https://hex.pm/packages/permit)**                           | [![Hex.pm](https://img.shields.io/hexpm/v/permit.svg)](https://hex.pm/packages/permit)                   | Core authorization library                 |
| **[permit_ecto](https://hex.pm/packages/permit_ecto)**                 | [![Hex.pm](https://img.shields.io/hexpm/v/permit_ecto.svg)](https://hex.pm/packages/permit_ecto)         | Ecto integration for database queries      |
| **[permit_phoenix](https://hex.pm/packages/permit_phoenix)**           | [![Hex.pm](https://img.shields.io/hexpm/v/permit_phoenix.svg)](https://hex.pm/packages/permit_phoenix)   | Phoenix Controllers & LiveView integration |
| **[permit_absinthe](https://github.com/curiosum-dev/permit_absinthe)** | [![Hex.pm](https://img.shields.io/hexpm/v/permit_absinthe.svg)](https://hex.pm/packages/permit_absinthe) | GraphQL API authorization via Absinthe     |

## Documentation

- **Permit.Phoenix docs**: [hexdocs.pm/permit_phoenix](https://hexdocs.pm/permit_phoenix)
- **Core library**: [hexdocs.pm/permit](https://hexdocs.pm/permit)
- **Ecto integration**: [hexdocs.pm/permit_ecto](https://hexdocs.pm/permit_ecto)
- **Absinthe integration**: [hexdocs.pm/permit_absinthe](https://hexdocs.pm/permit_absinthe)

## Contributing

We welcome contributions! Please see our [Contributing Guide](https://github.com/curiosum-dev/permit_phoenix/blob/master/CONTRIBUTING.md) for details.

### Development setup

Just clone the repository, install dependencies normally, develop and run tests. When running Credo and Dialyzer, please use `MIX_ENV=test` to ensure tests and support files are validated, too.

### Community

- **Slack channel**: [Elixir Slack / #permit](https://elixir-lang.slack.com/archives/C091Q5S0GDU)
- **Issues**: [GitHub Issues](https://github.com/curiosum-dev/permit_phoenix/issues)
- **Discussions**: [GitHub Discussions](https://github.com/curiosum-dev/permit/discussions)
- **Blog**: [Curiosum Blog](https://curiosum.com/blog?search=permit)

## Contact

- Library maintainer: [Michał Buszkiewicz](https://github.com/vincentvanbush)
- [**Curiosum**](https://curiosum.com) - Elixir development team behind Permit

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
