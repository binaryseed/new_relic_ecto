defmodule MyRouter do
  use Plug.Router
  use NewRelic.Transaction

  plug(:match)
  plug(:dispatch)

  get "/hello" do
    {:ok, _} = SampleApp.Repo.insert(%SampleApp.Count{})
    count = SampleApp.Repo.aggregate(SampleApp.Count, :count)

    response = %{hello: "world", count: count} |> Jason.encode!()

    Process.sleep(100)
    send_resp(conn, 200, response)
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
