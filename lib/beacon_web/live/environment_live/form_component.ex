defmodule BeaconWeb.EnvironmentLive.FormComponent do
  @moduledoc "The \"new environment\" form, shown in a modal from `EnvironmentLive.Index`."

  use BeaconWeb, :live_component

  alias Beacon.Flags

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>A place a flag is evaluated — "production", "staging", and so on.</:subtitle>
      </.header>

      <.simple_form for={@form} id="environment-form" phx-target={@myself} phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" placeholder="production" />
        <:actions>
          <.button phx-disable-with="Saving...">Save environment</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign(:form, to_form(Flags.change_environment()))}
  end

  @impl true
  def handle_event("save", %{"environment" => params}, socket) do
    case Flags.create_environment(socket.assigns.current_user, params) do
      {:ok, environment} ->
        notify_parent({:saved, environment})

        {:noreply,
         socket |> put_flash(:info, "Environment created") |> push_patch(to: socket.assigns.patch)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
