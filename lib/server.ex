defmodule Server do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> send_resp(200, "Ok")
  end

  match _ do
    conn
    |> send_resp(404, "Page not found")
  end

  def start_link(_) do
    Plug.Cowboy.http(Server, [])
  end
end
