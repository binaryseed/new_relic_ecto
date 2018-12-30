defmodule NewRelic.Ecto.TelemetryHandler do
  def handle_event(event, time, metadata, config) do
    IO.inspect({:handle_event, event, time, metadata, config})
  end
end
