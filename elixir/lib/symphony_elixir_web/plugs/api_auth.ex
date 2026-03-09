defmodule SymphonyElixirWeb.Plugs.ApiAuth do
  @moduledoc """
  Optional Bearer token authentication for the observability API.

  When `SYMPHONY_API_TOKEN` is set, all requests must include a matching
  `Authorization: Bearer <token>` header. When the env var is unset or
  empty, requests pass through without authentication.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case required_token() do
      nil ->
        conn

      expected_token ->
        case get_bearer_token(conn) do
          ^expected_token ->
            conn

          _ ->
            conn
            |> put_status(401)
            |> Phoenix.Controller.json(%{
              error: %{code: "unauthorized", message: "Invalid or missing API token"}
            })
            |> halt()
        end
    end
  end

  defp required_token do
    case System.get_env("SYMPHONY_API_TOKEN") do
      nil -> nil
      "" -> nil
      token -> token
    end
  end

  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> String.trim(token)
      _ -> nil
    end
  end
end
