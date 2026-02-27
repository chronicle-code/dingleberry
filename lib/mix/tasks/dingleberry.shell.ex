defmodule Mix.Tasks.Dingleberry.Shell do
  @moduledoc """
  Interactive shell interceptor. Reads commands from stdin,
  classifies them, and routes through the approval queue.

  Usage:
      mix dingleberry.shell
  """

  @shortdoc "Start interactive shell interceptor"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("Dingleberry Shell Interceptor")
    IO.puts("Type commands to classify and execute. Ctrl+C to exit.\n")

    loop()
  end

  defp loop do
    case IO.gets("dingleberry> ") do
      :eof ->
        IO.puts("\nGoodbye!")

      {:error, _reason} ->
        IO.puts("\nGoodbye!")

      input ->
        command = String.trim(input)

        unless command == "" do
          handle_command(command)
        end

        loop()
    end
  end

  defp handle_command(command) do
    case Dingleberry.Shell.Interceptor.execute(command) do
      {:ok, %{output: output, exit_code: 0}} ->
        IO.write(output)

      {:ok, %{output: output, exit_code: code}} ->
        IO.write(output)
        IO.puts("[exit: #{code}]")

      {:blocked, reason} ->
        IO.puts("BLOCKED: #{reason}")

      {:rejected, reason} ->
        IO.puts("REJECTED: #{reason}")

      {:error, reason} ->
        IO.puts("ERROR: #{reason}")
    end
  end
end
