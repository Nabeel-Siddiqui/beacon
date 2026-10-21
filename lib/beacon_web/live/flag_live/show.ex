defmodule BeaconWeb.FlagLive.Show do
  @moduledoc """
  One flag's dashboard: its current state in every environment, and the
  audit log of every change ever made to it — live, via
  `Flags.subscribe_to_flag/1`, so a change made from another tab or
  another person shows up here with no reload.
  """

  use BeaconWeb, :live_view

  alias Beacon.Flags

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Flags.get_flag(socket.assigns.current_user, id) do
      {:ok, flag} ->
        if connected?(socket), do: Flags.subscribe_to_flag(flag)

        {:ok,
         socket
         |> assign(:flag, flag)
         |> assign(:page_title, flag.key)
         |> assign(:environments, Flags.list_environments(socket.assigns.current_user))
         |> load_state()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "That flag doesn't exist.")
         |> push_navigate(to: ~p"/flags")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@flag.key}
      <:subtitle>{@flag.description}</:subtitle>
      <:actions>
        <.back navigate={~p"/flags"}>Back to flags</.back>
      </:actions>
    </.header>

    <.header class="mt-10">State by environment</.header>
    <div :if={@environments == []} class="mt-4 text-sm text-zinc-500">
      No environments yet.
      <.link navigate={~p"/environments/new"} class="underline">Create one</.link>
      to set this flag's state somewhere.
    </div>
    <div
      :for={environment <- @environments}
      class="mt-4 flex items-center gap-4 border-b border-zinc-100 pb-4"
    >
      <span class="w-32 font-medium text-zinc-900">{environment.name}</span>
      <form phx-submit="update_state" class="flex items-center gap-3">
        <input type="hidden" name="environment_id" value={environment.id} />
        <label class="flex items-center gap-2 text-sm text-zinc-700">
          <input
            type="checkbox"
            name="enabled"
            value="true"
            checked={state_for(@flag_states, environment.id).enabled}
          /> Enabled
        </label>
        <input
          type="number"
          name="rollout_percentage"
          min="0"
          max="100"
          value={state_for(@flag_states, environment.id).rollout_percentage}
          class="w-20 rounded-lg border-zinc-300 text-sm"
        />
        <span class="text-sm text-zinc-500">%</span>
        <.button type="submit">Save</.button>
      </form>
    </div>

    <.header class="mt-10">Audit log</.header>
    <.table id="audit-log" rows={@audit_log}>
      <:col :let={entry} label="When">
        {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M:%S")}
      </:col>
      <:col :let={entry} label="Environment">{entry.environment.name}</:col>
      <:col :let={entry} label="Enabled">{entry.enabled}</:col>
      <:col :let={entry} label="Rollout">{entry.rollout_percentage}%</:col>
      <:col :let={entry} label="Changed by">{entry.user && entry.user.email}</:col>
    </.table>
    <p :if={@audit_log == []} class="mt-4 text-sm text-zinc-500">
      No changes recorded yet.
    </p>
    """
  end

  @impl true
  def handle_event("update_state", %{"environment_id" => environment_id} = params, socket) do
    environment =
      Enum.find(socket.assigns.environments, &(&1.id == String.to_integer(environment_id)))

    attrs = %{
      enabled: params["enabled"] == "true",
      rollout_percentage: params["rollout_percentage"]
    }

    case Flags.set_flag_state(
           socket.assigns.current_user,
           socket.assigns.flag,
           environment,
           attrs
         ) do
      {:ok, _state} ->
        {:noreply, load_state(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't save that — rollout must be 0-100")}
    end
  end

  @impl true
  def handle_info({:flag_updated, _flag_id}, socket) do
    {:noreply, load_state(socket)}
  end

  defp load_state(socket) do
    flag = socket.assigns.flag

    flag_states =
      Map.new(socket.assigns.environments, fn environment ->
        {environment.id, Flags.get_flag_state(flag, environment)}
      end)

    socket
    |> assign(:flag_states, flag_states)
    |> assign(:audit_log, Flags.list_audit_log(flag))
  end

  defp state_for(flag_states, environment_id), do: Map.fetch!(flag_states, environment_id)
end
