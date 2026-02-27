defmodule Dingleberry.Shell.Parser do
  @moduledoc """
  Tokenizes shell commands to extract the executable and arguments.
  """

  @doc "Parse a command string into {executable, args_list, full_command}"
  def parse(command) when is_binary(command) do
    command = String.trim(command)

    case tokenize(command) do
      [] -> {:error, :empty_command}
      [executable | args] -> {:ok, %{executable: executable, args: args, raw: command}}
    end
  end

  @doc "Extract the base executable name (handles paths, env vars, sudo)"
  def executable_name(command) do
    case parse(command) do
      {:ok, %{executable: exec, args: args}} -> unwrap_executable(exec, args)
      {:error, _} -> nil
    end
  end

  @doc "Check if command contains pipe operators"
  def piped?(command), do: String.contains?(command, "|")

  @doc "Check if command contains redirections"
  def redirected?(command), do: Regex.match?(~r/[><]/, command)

  @doc "Check if command chains multiple commands"
  def chained?(command), do: Regex.match?(~r/[;&]|&&|\|\|/, command)

  @doc "Split a piped command into individual commands"
  def split_pipes(command) do
    command
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # Private

  defp tokenize(command) do
    # Simple tokenizer that handles basic quoting
    command
    |> String.trim()
    |> do_tokenize([], "", false, nil)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp do_tokenize("", acc, current, _in_escape, _quote_char) do
    [current | acc]
  end

  defp do_tokenize(<<"\\", char, rest::binary>>, acc, current, false, quote_char) do
    do_tokenize(rest, acc, current <> <<char>>, false, quote_char)
  end

  defp do_tokenize(<<"\"", rest::binary>>, acc, current, false, nil) do
    do_tokenize(rest, acc, current, false, "\"")
  end

  defp do_tokenize(<<"\"", rest::binary>>, acc, current, false, "\"") do
    do_tokenize(rest, acc, current, false, nil)
  end

  defp do_tokenize(<<"'", rest::binary>>, acc, current, false, nil) do
    do_tokenize(rest, acc, current, false, "'")
  end

  defp do_tokenize(<<"'", rest::binary>>, acc, current, false, "'") do
    do_tokenize(rest, acc, current, false, nil)
  end

  defp do_tokenize(<<" ", rest::binary>>, acc, current, false, nil) do
    do_tokenize(String.trim_leading(rest), [current | acc], "", false, nil)
  end

  defp do_tokenize(<<char, rest::binary>>, acc, current, false, quote_char) do
    do_tokenize(rest, acc, current <> <<char>>, false, quote_char)
  end

  defp unwrap_executable(exec, args) do
    base = Path.basename(exec)

    case base do
      "sudo" -> if args != [], do: Path.basename(hd(args)), else: "sudo"
      "env" -> skip_env_args(args)
      other -> other
    end
  end

  defp skip_env_args([]), do: "env"

  defp skip_env_args([arg | rest]) do
    if String.contains?(arg, "=") do
      skip_env_args(rest)
    else
      Path.basename(arg)
    end
  end
end
