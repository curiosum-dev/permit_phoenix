# Permit.Phoenix

[![Hex version badge](https://img.shields.io/hexpm/v/permit_phoenix.svg)](https://hex.pm/packages/permit_phoenix)
[![Actions Status](https://github.com/curiosum-dev/permit_phoenix/actions/workflows/elixir.yml/badge.svg)](https://github.com/curiosum-dev/permit_phoenix/actions)
[![Code coverage badge](https://img.shields.io/codecov/c/github/curiosum-dev/permit_phoenix/master.svg)](https://codecov.io/gh/curiosum-dev/permit_phoenix/branch/master)
[![License badge](https://img.shields.io/hexpm/l/permit_phoenix.svg)](https://github.com/curiosum-dev/permit_phoenix/blob/master/LICENSE.md)

[Phoenix Framework](https://hexdocs.pm/phoenix) and [LiveView](https://hexdocs.pm/phoenix_live_view) integration for [Permit](https://hexdocs.pm/permit) authorization library.

## Purpose and usage

`Permit.Phoenix` allows for consistent authorization of actions throughout the entire codebase of a Phoenix application, both in Plug-based controllers and in LiveView.
- [`Permit`](https://hexdocs.pm/permit) provides the permission definition syntax
- [`Permit.Ecto`](https://hexdocs.pm/permit_ecto) is optional, but - if present - it constructs queries to look up accessible records from a database, based on defined permissions
- `Permit.Phoenix` plugs into controllers and live views in order to automatically preload records and check authorization permissions to perform actions.

### Installation

The package can be installed by adding `permit_phoenix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:permit_phoenix, "~> 0.1.0"},
    # :permit_ecto can be omitted if Ecto is not used
    {:permit_ecto, "~> 0.1.1"}
  ]
end
```

### Configuration

While in basic Permit all actions must be defined in a module implementing the `Permit.Actions` behaviour, in the `grouping_schema/0` callback implementation, in Phoenix it is potentially inconvenient - adding a new controller action name would require adding it to the `grouping_schema/0` implementation every single time.

For this reason, **Permit.Phoenix provides the `Permit.Phoenix.Actions` module**, building upon the standard way of defining action names with `Permit.Actions` and additionally enabling you to automatically define actions based on controller and LiveView actions defined in the router.

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

The `view/3` and `watch/3` functions are shorthands to `permission_to/4` in which the first argument would've been `:view` or `:watch`, respectively - they're generated based on the module implementing `grouping_schema/0` callback from `Permit.Actions`.

## Default action mapping

By default, `Permit.Phoenix.Actions` provides the following action mapping:
```elixir
%{
  new: [:create],
  index: [:read],
  show: [:read],
  edit: [:update]
}
```
This means that accessing the `:new` action will require the `:create` permission, accessing the `:index` or `:show` action will require the `:read` permission, and accessing `:edit` will require the `:update` permission - this is for convenience when using default Phoenix action names.

```elixir
def can(_user) do
  permit()
  |> read(MyApp.Item) # allows :index and :show
end
```

### Controllers

All options of `Permit.Phoenix.Controller` can be provided as option keywords with `use Permit.Phoenix.Controller` or as callback implementations. For example, defining a `handle_unauthorized: fn action, conn -> ... end` option is equivalent to:
```elixir
@impl true
def handle_unauthorized(action, conn), do: ...
```

In practice, it depends on use case:
* when providing options for different actions, etc., consider using callback implementations
* if you want to provide values as literals instead of functions, consider using option keywords
* for global settings throughout controllers using `use MyAppWeb, :controller`, set globals as keywords, and override in specific controllers using callback implementations.

Whenever `resolution_context` is referred to, it is typified by `Permit.Types.resolution_context`.

#### One-off usage

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

#### Global usage with settings in specific controllers
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
  def resource_module, do: MyAppArticle

  # etc., etc.
end
```

### LiveView

#### Router configuration

```elixir
defmodule MyAppWeb.Router do
  # ...

  scope "/", MyAppWeb do
    # ...

    # Configure using an :on_mount hook
    live_session :my_app_session, on_mount: Permit.Phoenix.LiveView.AuthorizeHook do
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

#### LiveView configuration

In a similar way to configuring controllers, LiveViews can be configured with option keywords or callback implementations, thus let's omit lengthy examples of both.

Most options are similar to controller options, with `socket` in place of `conn`.

Note that it is mandatory to implement the `fetch_subject` callback, so it is recommended to put it as shared configuration in your web app module.

```elixir
defmodule PermitTestWeb.ArticleLive.Index do
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

  @impl true
  def fetch_subject(_socket, session) do
    # Retrieve the current user from session
  end
end
```
