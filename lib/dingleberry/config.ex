defmodule Dingleberry.Config do
  @moduledoc """
  Reads and manages Dingleberry configuration from ~/.dingleberry/config.yml
  """

  @config_dir Path.expand("~/.dingleberry")
  @config_file Path.join(@config_dir, "config.yml")
  @db_file Path.join(@config_dir, "dingleberry.db")
  @default_policy_file Path.join(@config_dir, "policy.yml")

  defstruct [
    :port,
    :db_path,
    :policy_path,
    :approval_timeout_seconds,
    :log_level,
    :desktop_notifications
  ]

  def config_dir, do: @config_dir
  def config_file, do: @config_file
  def db_path, do: @db_file
  def default_policy_file, do: @default_policy_file

  @doc "Load config from ~/.dingleberry/config.yml, falling back to defaults"
  def load do
    ensure_dirs!()

    case File.read(@config_file) do
      {:ok, content} ->
        {:ok, yaml} = YamlElixir.read_from_string(content)
        parse(yaml)

      {:error, :enoent} ->
        defaults()
    end
  end

  @doc "Ensure ~/.dingleberry/ directory structure exists"
  def ensure_dirs! do
    File.mkdir_p!(@config_dir)
  end

  @doc "Copy default policy to ~/.dingleberry/policy.yml if missing"
  def ensure_default_policy! do
    unless File.exists?(@default_policy_file) do
      source = Application.app_dir(:dingleberry, "priv/policies/default.yml")

      if File.exists?(source) do
        File.cp!(source, @default_policy_file)
      end
    end
  end

  defp parse(yaml) when is_map(yaml) do
    %__MODULE__{
      port: Map.get(yaml, "port", 4000),
      db_path: Map.get(yaml, "db_path", @db_file),
      policy_path: Map.get(yaml, "policy_path", @default_policy_file),
      approval_timeout_seconds: Map.get(yaml, "approval_timeout_seconds", 120),
      log_level: Map.get(yaml, "log_level", "info") |> String.to_atom(),
      desktop_notifications: Map.get(yaml, "desktop_notifications", true)
    }
  end

  defp defaults do
    %__MODULE__{
      port: 4000,
      db_path: @db_file,
      policy_path: @default_policy_file,
      approval_timeout_seconds: 120,
      log_level: :info,
      desktop_notifications: true
    }
  end
end
