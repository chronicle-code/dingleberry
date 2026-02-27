defmodule Dingleberry.MCP.Codec do
  @moduledoc """
  JSON-RPC 2.0 codec for MCP protocol messages.
  Handles encoding/decoding and identifying tool calls.
  """

  @doc "Decode a JSON-RPC message from a binary string"
  def decode(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} -> {:error, {:json_decode, reason}}
    end
  end

  @doc "Encode a JSON-RPC message to a binary string"
  def encode(message) when is_map(message) do
    Jason.encode(message)
  end

  @doc "Check if a decoded message is a tools/call request"
  def tool_call?(%{"method" => "tools/call"} = _msg), do: true
  def tool_call?(_), do: false

  @doc "Check if a decoded message is a JSON-RPC request (has method)"
  def request?(%{"method" => _}), do: true
  def request?(_), do: false

  @doc "Check if a decoded message is a JSON-RPC response (has result or error)"
  def response?(%{"result" => _}), do: true
  def response?(%{"error" => _}), do: true
  def response?(_), do: false

  @doc "Extract tool name and arguments from a tools/call request"
  def extract_tool_info(%{"method" => "tools/call", "params" => params}) do
    name = Map.get(params, "name", "unknown")
    arguments = Map.get(params, "arguments", %{})
    {:ok, %{name: name, arguments: arguments}}
  end

  def extract_tool_info(_), do: {:error, :not_a_tool_call}

  @doc "Build a tool call description string for policy matching"
  def tool_call_description(%{name: name, arguments: args}) do
    args_str =
      args
      |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
      |> Enum.join(", ")

    "#{name}(#{args_str})"
  end

  @doc "Build a JSON-RPC error response"
  def error_response(id, code, message) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }
  end

  @doc "Build a JSON-RPC success response"
  def success_response(id, result) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    }
  end

  @doc "Extract the request ID from a message"
  def request_id(%{"id" => id}), do: id
  def request_id(_), do: nil

  @doc """
  Read a single JSON-RPC message from an IO stream.
  MCP uses newline-delimited JSON over stdio.
  """
  def read_message(io_device) do
    case IO.read(io_device, :line) do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      data -> decode(String.trim(data))
    end
  end

  @doc "Write a JSON-RPC message to an IO stream"
  def write_message(io_device, message) do
    case encode(message) do
      {:ok, json} ->
        IO.write(io_device, json <> "\n")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
