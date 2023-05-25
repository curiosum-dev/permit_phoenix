defmodule Permit.Phoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :permit_phoenix,
      version: "0.0.2",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Phoenix, Plug and LiveView integrations for the Permit authorization library.",
      package: package()
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
      {:permit, "~> 0.0.3"},
      {:permit_ecto, "~> 0.0.2", only: :test},
      {:ecto, "~> 3.0", only: :test},
      {:ecto_sql, "~> 3.0", only: :test},
      {:postgrex, "~> 0.16", only: :test},
      {:phoenix_live_view, "#{live_view_version()}", optional: true},
      {:phoenix, "#{phoenix_version()}", optional: true},
      {:jason, "~> 1.3", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp live_view_version() do
    System.get_env("LIVE_VIEW_VERSION", "~> 0.17")
  end

  defp phoenix_version() do
    System.get_env("LIVE_VIEW_VERSION", "~> 1.6")
  end
end
