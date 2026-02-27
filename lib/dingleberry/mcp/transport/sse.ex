defmodule Dingleberry.MCP.Transport.SSE do
  @moduledoc """
  HTTP/SSE transport helpers for MCP proxy.
  The actual Phoenix controller is at DingleberryWeb.MCPController.
  This module provides shared utilities for SSE transport management.
  """

  @doc "Format a Server-Sent Event"
  def format_event(event, data) do
    "event: #{event}\ndata: #{data}\n\n"
  end

  @doc "Format a keepalive comment"
  def keepalive, do: ": keepalive\n\n"
end
