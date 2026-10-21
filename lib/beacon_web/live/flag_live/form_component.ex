defmodule BeaconWeb.FlagLive.FormComponent do
  @moduledoc "The \"new flag\" form, shown in a modal from `FlagLive.Index`."

  use BeaconWeb, :live_component

  alias Beacon.Flags

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Starts off at 0% everywhere until you set it per environment.</:subtitle>
      </.header>

      <.simple_form for={@form} id="flag-form" phx-target={@myself} phx-submit="save">
        <.input field={@form[:key]} type="text" label="Key" placeholder="new-dashboard" />
        <.input field={@form[:description]} type="text" label="Description" />
        <:actions>
          <.button phx-disable-with="Saving...">Save flag</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign(:form, to_form(Flags.change_flag()))}
  end

  @impl true
  def handle_event("save", %{"flag" => params}, socket) do
    case Flags.create_flag(socket.assigns.current_user, params) do
      {:ok, flag} ->
        notify_parent({:saved, flag})

        {:noreply,
         socket |> put_flash(:info, "Flag created") |> push_patch(to: socket.assigns.patch)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
