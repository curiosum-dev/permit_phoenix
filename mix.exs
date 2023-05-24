defmodule Permit.Phoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :permit_phoenix,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:permit, path: "../permit"},
      {:permit_ecto, path: "../permit_ecto", only: :test},
      {:ecto, "~> 3.0", only: :test},
      {:ecto_sql, "~> 3.0", only: :test},
      {:postgrex, "~> 0.16", only: :test},
      {:phoenix_live_view, "#{live_view_version()}", optional: true},
      {:phoenix, "~> 1.6", optional: true},
      {:jason, "~> 1.3", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp live_view_version() do
    System.get_env("LIVE_VIEW_VERSION", "~> 0.17.0")
  end
end
