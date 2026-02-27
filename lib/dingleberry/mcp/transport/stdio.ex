defmodule Dingleberry.MCP.Transport.Stdio do
  @moduledoc """
  Stdio transport for MCP proxy. Spawns the real MCP server as a Port
  and proxies messages bidirectionally, intercepting tool calls.
  """

  use GenServer

  require Logger

  alias Dingleberry.MCP.{Codec, Proxy}

  defstruct [:port, :proxy_pid, :buffer]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    command = Keyword.fetch!(opts, :command)
    args = Keyword.get(opts, :args, [])

    {:ok, proxy_pid} =
      Proxy.start_link(
        session_id: Keyword.get(opts, :session_id, Uniq.UUID.uuid4()),
        transport: :stdio
      )

    port =
      Port.open({:spawn_executable, find_executable(command)}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: args,
        env: Keyword.get(opts, :env, [])
      ])

    # Start reading from stdin in a separate process
    parent = self()

    spawn_link(fn ->
      stdin_reader(parent)
    end)

    {:ok, %__MODULE__{port: port, proxy_pid: proxy_pid, buffer: ""}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Data from real MCP server -> forward to AI agent (stdout)
    IO.write(:stdio, data)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.info("MCP server exited with status #{status}")
    {:stop, :normal, state}
  end

  def handle_info({:stdin, data}, state) do
    # Data from AI agent (stdin) -> intercept and maybe forward to MCP server
    buffer = state.buffer <> data

    {messages, remaining} = split_messages(buffer)

    Enum.each(messages, fn msg ->
      handle_agent_message(msg, state)
    end)

    {:noreply, %{state | buffer: remaining}}
  end

  # Private

  defp handle_agent_message(raw_message, state) do
    case Proxy.process_message(state.proxy_pid, raw_message) do
      {:forward, _message} ->
        # Forward original raw message to real MCP server
        Port.command(state.port, raw_message <> "\n")

      {:respond, response} ->
        # Send intercepted response back to AI agent
        {:ok, json} = Codec.encode(response)
        IO.write(:stdio, json <> "\n")
    end
  end

  defp stdin_reader(parent) do
    case IO.read(:stdio, :line) do
      :eof ->
        :ok

      {:error, _reason} ->
        :ok

      data ->
        send(parent, {:stdin, String.trim_trailing(data, "\n")})
        stdin_reader(parent)
    end
  end

  defp split_messages(buffer) do
    lines = String.split(buffer, "\n")

    case List.last(lines) do
      "" ->
        # Buffer ended with newline, all lines are complete
        messages = lines |> Enum.reject(&(&1 == "")) |> Enum.map(&String.trim/1)
        {messages, ""}

      partial ->
        # Last line is incomplete
        complete = lines |> Enum.drop(-1) |> Enum.reject(&(&1 == "")) |> Enum.map(&String.trim/1)
        {complete, partial}
    end
  end

  defp find_executable(command) do
    case System.find_executable(command) do
      nil -> raise "Executable not found: #{command}"
      path -> path
    end
  end
end
