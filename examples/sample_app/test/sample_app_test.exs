defmodule SampleAppTest do
  use ExUnit.Case

  test "basic HTTP request" do
    {:ok, %{body: body}} = request()
    assert body =~ "world"
  end

  def request() do
    {:ok, {{_, _status_code, _}, _headers, body}} = :httpc.request('http://localhost:4001/hello')
    {:ok, %{body: to_string(body)}}
  end
end
