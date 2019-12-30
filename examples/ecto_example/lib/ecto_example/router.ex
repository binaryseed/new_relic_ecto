defmodule EctoExample.Router do
  use Plug.Router
  use NewRelic.Transaction
  use NewRelic.Tracer

  plug(:match)
  plug(:dispatch)

  get "/hello" do
    count = query_db()
    response = %{hello: "world", count: count} |> Jason.encode!()

    Process.sleep(100)
    send_resp(conn, 200, response)
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  @trace :query_db
  def query_db() do
    {:ok, _} = EctoExample.Repo.insert(%EctoExample.Count{})
    Process.sleep(20)
    EctoExample.Repo.aggregate(EctoExample.Count, :count)
  end
end
