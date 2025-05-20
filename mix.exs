defmodule Permit.Phoenix.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.2.0"
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
      dialyzer: [plt_add_apps: [:ex_unit, :permit_ecto]],
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/curiosum-dev/permit_phoenix/"},
      maintainers: ["Michał Buszkiewicz", "Piotr Lisowski"],
      files: ["lib", "mix.exs", "README*"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications:
        case Mix.env() do
          :test -> [:logger, :plug, :phoenix_live_view]
          :dev -> [:logger, :plug, :phoenix_live_view]
          _ -> [:logger]
        end
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/support/", "test/permit/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:permit, "~> 0.2"},
      {:permit_ecto, "~> 0.2.1", only: :test},
      {:ecto, "~> 3.0", only: :test},
      {:ecto_sql, "~> 3.0", only: :test},
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
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Permit.Phoenix",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp live_view_version do
    System.get_env("LIVE_VIEW_VERSION", ">= 0.20.0")
  end

  defp phoenix_version do
    System.get_env("PHOENIX_VERSION", "~> 1.6")
  end
end
