defmodule BeaconWeb.API.FlagController do
  use BeaconWeb, :controller

  alias Beacon.Flags

  @doc """
  `GET /api/flags/:key/enabled?environment=staging&subject=user-123`

  Evaluates one flag for one subject, scoped to the API token's owner.
  Always returns 200 with `enabled: false` for an unknown flag,
  environment, or subject — the same fail-safe default
  `Flags.enabled?/4` itself uses, so a typo in a flag key never looks
  any different from a flag that's genuinely off.
  """
  def enabled(conn, %{"key" => key} = params) do
    with {:ok, environment} <- require_param(params, "environment"),
         {:ok, subject} <- require_param(params, "subject") do
      enabled? = Flags.enabled?(conn.assigns.current_user, key, environment, subject)
      json(conn, %{flag: key, environment: environment, subject: subject, enabled: enabled?})
    else
      {:error, missing} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "missing required query parameter: #{missing}"})
    end
  end

  defp require_param(params, name) do
    case Map.fetch(params, name) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, name}
    end
  end
end
