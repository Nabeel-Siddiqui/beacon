defmodule BeaconWeb.ApiAuth do
  @moduledoc """
  Authenticates API requests by a bearer API token, instead of the
  browser session `BeaconWeb.UserAuth` handles. Used only by the
  `:api` router pipeline.
  """

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller

  alias Beacon.Accounts
  alias Beacon.Accounts.User

  @impl Plug
  def init(opts), do: opts

  @doc """
  Assigns `:current_user` from the `Authorization: Bearer <token>`
  header. Halts with a 401 if the header is missing or the token is
  invalid — there's no browser session fallback on this pipeline.
  """
  @impl Plug
  def call(conn, opts), do: fetch_current_user(conn, opts)

  defp fetch_current_user(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         %User{} = user <- Accounts.get_user_by_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "missing or invalid API token"})
    |> halt()
  end
end
