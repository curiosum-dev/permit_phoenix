defmodule Permit.Phoenix.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/curiosum-dev/permit_phoenix"

  def project do
    [
      app: :permit_phoenix,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Phoenix, Plug and LiveView integrations for the Permit authorization library.",
      package: package(),
      dialyzer: [
        plt_add_apps: [:ex_unit, :permit, :phoenix, :phoenix_live_view, :plug],
        plt_ignore_apps: [:ecto, :ecto_sql, :permit_ecto],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true,
        flags: [:unmatched_returns, :error_handling]
      ],
      docs: docs(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/curiosum-dev/permit_phoenix/"},
      maintainers: ["Michał Buszkiewicz"],
      files: ["lib", "mix.exs", "README*"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications:
        case Mix.env() do
          :test -> [:logger, :ecto_sql, :plug, :phoenix_live_view]
          :dev -> [:logger, :plug, :phoenix_live_view]
          _ -> [:logger]
        end
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/support/", "test/permit/support"]
  defp elixirc_paths(:dev), do: ["lib", "docs.ex"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:permit, "~> 0.3.2"},
      {:permit_ecto, "~> 0.2", optional: true},
      {:ecto, "~> 3.0", optional: true},
      {:ecto_sql, "~> 3.0", optional: true},
      {:postgrex, "~> 0.16", only: :test},
      {:phoenix_live_view, "#{live_view_version()}", optional: true},
      {:phoenix, "#{phoenix_version()}", optional: true},
      {:jason, "~> 1.3", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:versioce, "~> 2.0.0", only: [:dev, :test], runtime: false},
      {:git_cli, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp docs do
    [
      main: "Permit.Phoenix",
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_modules: [
        Controllers: [Permit.Phoenix.Controller, Permit.Phoenix.Plug],
        LiveView: [Permit.Phoenix.LiveView, Permit.Phoenix.LiveView.AuthorizeHook],
        "Configuring actions": [Permit.Phoenix.Actions],
        "Types and errors": [Permit.Phoenix.Types, ~r/.+Error/]
      ],
      before_closing_body_tag: &Permit.Phoenix.Docs.before_closing_body_tag/1
    ]
  end

  defp live_view_version do
    System.get_env("LIVE_VIEW_VERSION", ">= 0.20.0")
  end

  defp phoenix_version do
    System.get_env("PHOENIX_VERSION", "~> 1.6")
  end
end
