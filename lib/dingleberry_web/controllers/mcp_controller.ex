defmodule DingleberryWeb.MCPController do
  use DingleberryWeb, :controller

  alias Dingleberry.MCP.{Codec, Proxy}

  def message(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    session_id = get_or_create_session(conn)
    proxy_pid = get_or_start_proxy(session_id)

    case Proxy.process_message(proxy_pid, body) do
      {:forward, _message} ->
        conn
        |> put_status(200)
        |> json(%{status: "forwarded"})

      {:respond, response} ->
        conn
        |> put_status(200)
        |> json(response)
    end
  end

  def sse(conn, _params) do
    session_id = get_or_create_session(conn)

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    {:ok, conn} = chunk(conn, sse_event("endpoint", "/mcp/message?session_id=#{session_id}"))
    Phoenix.PubSub.subscribe(Dingleberry.PubSub, "mcp:#{session_id}")

    sse_loop(conn)
  end

  defp sse_loop(conn) do
    receive do
      {:mcp_event, event_type, data} ->
        case Codec.encode(data) do
          {:ok, json_str} ->
            case chunk(conn, sse_event(event_type, json_str)) do
              {:ok, conn} -> sse_loop(conn)
              {:error, _} -> conn
            end

          {:error, _} ->
            sse_loop(conn)
        end

      :close ->
        conn
    after
      30_000 ->
        case chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end
    end
  end

  defp sse_event(event, data) do
    "event: #{event}\ndata: #{data}\n\n"
  end

  defp get_or_create_session(conn) do
    conn.params["session_id"] || Uniq.UUID.uuid4()
  end

  defp get_or_start_proxy(session_id) do
    case Registry.lookup(Dingleberry.ProxyRegistry, session_id) do
      [{pid, _}] ->
        pid

      [] ->
        {:ok, pid} = Proxy.start_link(session_id: session_id, transport: :sse)
        Registry.register(Dingleberry.ProxyRegistry, session_id, pid)
        pid
    end
  end
end
