defmodule BeaconWeb.FlagLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Flags
  alias Beacon.Flags.Flag

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :flags, Flags.list_flags(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Flags") |> assign(:flag, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Flag") |> assign(:flag, %Flag{})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Flags
      <:subtitle>Every feature you're toggling.</:subtitle>
      <:actions>
        <.link patch={~p"/flags/new"}>
          <.button>New flag</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="flags" rows={@flags} row_click={fn flag -> JS.navigate(~p"/flags/#{flag}") end}>
      <:col :let={flag} label="Key">{flag.key}</:col>
      <:col :let={flag} label="Description">{flag.description}</:col>
    </.table>

    <p :if={@flags == []} class="mt-6 text-sm text-zinc-500">
      No flags yet. Create one to start rolling out a feature.
    </p>

    <.modal :if={@live_action == :new} id="flag-modal" show on_cancel={JS.patch(~p"/flags")}>
      <.live_component
        module={BeaconWeb.FlagLive.FormComponent}
        id={:new}
        title={@page_title}
        action={@live_action}
        flag={@flag}
        current_user={@current_user}
        patch={~p"/flags"}
      />
    </.modal>
    """
  end

  @impl true
  def handle_info({BeaconWeb.FlagLive.FormComponent, {:saved, _flag}}, socket) do
    {:noreply, assign(socket, :flags, Flags.list_flags(socket.assigns.current_user))}
  end
end
