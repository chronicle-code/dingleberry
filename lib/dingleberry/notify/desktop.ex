defmodule Dingleberry.Notify.Desktop do
  @moduledoc """
  Desktop notifications for intercepted commands.
  Uses osascript on macOS and notify-send on Linux.
  """

  require Logger

  @doc "Send a desktop notification for a pending approval request"
  def notify(%{command: command, risk: risk}) do
    title = "Dingleberry: #{risk_label(risk)} Command Intercepted"
    body = truncate(command, 100)

    case :os.type() do
      {:unix, :darwin} -> macos_notify(title, body)
      {:unix, _} -> linux_notify(title, body)
      _ -> Logger.debug("Desktop notifications not supported on this platform")
    end
  end

  defp macos_notify(title, body) do
    script = ~s(display notification "#{escape(body)}" with title "#{escape(title)}" sound name "Purr")

    Task.start(fn ->
      System.cmd("osascript", ["-e", script], stderr_to_stdout: true)
    end)
  end

  defp linux_notify(title, body) do
    Task.start(fn ->
      System.cmd("notify-send", ["-u", "critical", title, body], stderr_to_stdout: true)
    end)
  end

  defp risk_label(:block), do: "BLOCKED"
  defp risk_label(:warn), do: "WARNING"
  defp risk_label(_), do: "INFO"

  defp escape(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."
end
