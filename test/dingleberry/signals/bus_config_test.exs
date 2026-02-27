defmodule Dingleberry.Signals.BusConfigTest do
  use ExUnit.Case

  alias Dingleberry.Signals.BusConfig
  alias Dingleberry.Signals.CommandIntercepted

  describe "bus_name/0" do
    test "returns the configured bus name" do
      assert BusConfig.bus_name() == :dingleberry_signal_bus
    end
  end

  describe "child_spec/0" do
    test "returns a valid child spec" do
      spec = BusConfig.child_spec()
      assert is_map(spec) or is_tuple(spec)
    end
  end

  describe "publish + subscribe" do
    test "delivers signals to subscribers" do
      # Subscribe to intercepted command signals
      BusConfig.subscribe("dingleberry.command.intercepted")

      # Create and publish a signal
      {:ok, signal} =
        CommandIntercepted.new(%{
          command: "rm -rf /tmp",
          source: "shell",
          risk: "warn",
          matched_rule: "destructive_rm"
        })

      BusConfig.publish(signal)

      # Signal bus delivers as {:signal, %Jido.Signal{}}
      assert_receive {:signal, %Jido.Signal{type: "dingleberry.command.intercepted"} = received}, 1000
      assert received.data.command == "rm -rf /tmp"
      assert received.data.risk == "warn"
    end
  end
end
