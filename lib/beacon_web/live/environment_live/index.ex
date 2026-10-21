defmodule BeaconWeb.EnvironmentLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Flags
  alias Beacon.Flags.Environment

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :environments, Flags.list_environments(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Environments") |> assign(:environment, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Environment") |> assign(:environment, %Environment{})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Environments
      <:subtitle>Every place you evaluate a flag in.</:subtitle>
      <:actions>
        <.link patch={~p"/environments/new"}>
          <.button>New environment</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="environments" rows={@environments}>
      <:col :let={environment} label="Name">{environment.name}</:col>
    </.table>

    <p :if={@environments == []} class="mt-6 text-sm text-zinc-500">
      No environments yet. Add one — "production" is a good start.
    </p>

    <.modal
      :if={@live_action == :new}
      id="environment-modal"
      show
      on_cancel={JS.patch(~p"/environments")}
    >
      <.live_component
        module={BeaconWeb.EnvironmentLive.FormComponent}
        id={:new}
        title={@page_title}
        action={@live_action}
        environment={@environment}
        current_user={@current_user}
        patch={~p"/environments"}
      />
    </.modal>
    """
  end

  @impl true
  def handle_info({BeaconWeb.EnvironmentLive.FormComponent, {:saved, _environment}}, socket) do
    {:noreply,
     assign(socket, :environments, Flags.list_environments(socket.assigns.current_user))}
  end
end
