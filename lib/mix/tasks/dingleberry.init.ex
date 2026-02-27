defmodule Mix.Tasks.Dingleberry.Init do
  @moduledoc "Scaffolds ~/.dingleberry/ with default config and policy"
  @shortdoc "Initialize Dingleberry config directory"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Dingleberry.Config.ensure_dirs!()

    config_file = Dingleberry.Config.config_file()

    unless File.exists?(config_file) do
      File.write!(config_file, default_config_yaml())
      Mix.shell().info("Created #{config_file}")
    else
      Mix.shell().info("Config already exists at #{config_file}")
    end

    policy_file = Dingleberry.Config.default_policy_file()

    unless File.exists?(policy_file) do
      source = Path.join([Mix.Project.app_path(), "priv", "policies", "default.yml"])

      if File.exists?(source) do
        File.cp!(source, policy_file)
        Mix.shell().info("Created #{policy_file}")
      else
        # Fallback: copy from project priv
        project_source = Path.join(["priv", "policies", "default.yml"])

        if File.exists?(project_source) do
          File.cp!(project_source, policy_file)
          Mix.shell().info("Created #{policy_file}")
        else
          Mix.shell().info("Default policy not found — run `mix compile` first")
        end
      end
    else
      Mix.shell().info("Policy already exists at #{policy_file}")
    end

    Mix.shell().info("Dingleberry initialized at #{Dingleberry.Config.config_dir()}")
  end

  defp default_config_yaml do
    """
    # Dingleberry Configuration
    # See https://github.com/dingleberry-ai/dingleberry for docs

    port: 4000
    approval_timeout_seconds: 120
    desktop_notifications: true
    log_level: info
    """
  end
end
