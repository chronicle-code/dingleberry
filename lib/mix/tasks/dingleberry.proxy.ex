defmodule Mix.Tasks.Dingleberry.Proxy do
  @moduledoc """
  Start Dingleberry as an MCP proxy in front of a real MCP server.

  Usage:
      mix dingleberry.proxy --command npx --args "@modelcontextprotocol/server-filesystem /tmp"
      mix dingleberry.proxy --command uvx --args "mcp-server-sqlite --db-path /tmp/test.db"
  """

  @shortdoc "Start MCP proxy in front of a real MCP server"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [command: :string, args: :string, transport: :string],
        aliases: [c: :command, a: :args, t: :transport]
      )

    command = Keyword.get(opts, :command) || raise "Missing --command flag"
    cmd_args = Keyword.get(opts, :args, "") |> String.split(" ", trim: true)

    Mix.Task.run("app.start")

    IO.puts(:stderr, "Dingleberry MCP Proxy")
    IO.puts(:stderr, "Proxying: #{command} #{Enum.join(cmd_args, " ")}")
    IO.puts(:stderr, "Dashboard: http://localhost:4000\n")

    {:ok, _pid} =
      Dingleberry.MCP.Transport.Stdio.start_link(
        command: command,
        args: cmd_args
      )

    # Keep the task running
    Process.sleep(:infinity)
  end
end
