defmodule TextDelta.Mixfile do
  use Mix.Project

  @version "1.7.2"
  @github_url "https://github.com/MeisterLabs/text_delta"

  def project do
    [
      app: :text_delta,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      homepage_url: @github_url,
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application, do: []

  defp aliases, do: []

  defp docs do
    [
      source_ref: "v#{@version}",
      extras: [
        "README.md": [filename: "README.md", title: "Readme"],
        "CHANGELOG.md": [filename: "CHANGELOG.md", title: "Changelog"],
        "LICENSE.md": [filename: "LICENSE.md", title: "License"]
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.15", only: [:dev], runtime: false},
      {:credo, "~> 1.5.4", only: [:dev, :test], runtime: false}
    ]
  end
end
