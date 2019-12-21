defmodule SampleAppTest do
  use ExUnit.Case
  doctest SampleApp

  test "greets the world" do
    assert SampleApp.hello() == :world
  end
end
