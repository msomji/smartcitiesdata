defmodule AndiWeb.EditLiveView do
  use AndiWeb, :live_view

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Services.DatasetStore

  import SmartCity.Event, only: [dataset_update: 0, dataset_delete: 0]
  require Logger

  @instance_name Andi.instance_name()

  def render(assigns) do
    ~L"""
    <div class="edit-page" id="dataset-edit-page">
      <div class="page-header">
        <button type="button" phx-click="cancel-edit" class="return-home-button btn btn--large"><div class="home-icon"></div>HOME</button>
        <div class="organization-link" phx-click="show-organizations">
          <div class="organization-link__icon"></div>
          <div class="organization-link__text">ORGANIZATIONS</div>
        </div>
      </div>

      <%= f = form_for @changeset, "" %>
        <% [business] = inputs_for(f, :business) %>
        <% [technical] = inputs_for(f, :technical) %>
        <%= hidden_input(f, :id) %>
        <%= hidden_input(f, :owner_id) %>
        <%= hidden_input(business, :authorEmail) %>
        <%= hidden_input(business, :authorName) %>
        <%= hidden_input(business, :categories) %>
        <%= hidden_input(business, :conformsToUri) %>
        <%= hidden_input(business, :describedByMimeType) %>
        <%= hidden_input(business, :describedByUrl) %>
        <%= hidden_input(business, :id) %>
        <%= hidden_input(business, :orgTitle) %>
        <%= hidden_input(business, :parentDataset) %>
        <%= hidden_input(business, :referenceUrls) %>
        <%= hidden_input(technical, :allow_duplicates) %>
        <%= hidden_input(technical, :authBodyEncodeMethod) %>
        <%= hidden_input(technical, :authUrl) %>
        <%= hidden_input(technical, :credentials) %>
        <%= hidden_input(technical, :dataName) %>
        <%= hidden_input(technical, :id) %>
        <%= hidden_input(technical, :orgId) %>
        <%= hidden_input(technical, :orgName) %>
        <%= hidden_input(technical, :protocol) %>
        <%= hidden_input(technical, :sourceFormat) %>
        <%= hidden_input(technical, :sourceType) %>
        <%= hidden_input(technical, :systemName) %>

        <div class="metadata-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.MetadataForm, id: :metadata_form_editor, session: %{"dataset" => @dataset}) %>
        </div>

        <div class="data-dictionary-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.DataDictionaryForm, id: :data_dictionary_form_editor, session: %{"dataset" => @dataset}) %>
        </div>

        <div class="extract-steps-form-component">
          <%= live_render(@sockey, AndiWeb.EditLiveView.ExtractStepForm, id: :extract_step_form_editor) %>
        </div>

        <div class="url-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.UrlForm, id: :url_form_editor, session: %{"dataset" => @dataset}) %>
        </div>

        <div class="finalize-form-component ">
          <%= live_render(@socket, AndiWeb.EditLiveView.FinalizeForm, id: :finalize_form_editor, session: %{"dataset" => @dataset}) %>
        </div>
      </form>

      <div class="edit-page__delete-btn">
        <button id="delete-dataset-button" name="delete-dataset-button" class="btn btn--delete btn--large" phx-click="dataset-delete" type="button">DELETE DATASET</button>
      </div>

      <%= live_component(@socket, AndiWeb.EditLiveView.UnsavedChangesModal, visibility: @unsaved_changes_modal_visibility) %>

      <%= live_component(@socket, AndiWeb.EditLiveView.PublishSuccessModal, visibility: @publish_success_modal_visibility) %>

      <%= live_component(@socket, AndiWeb.EditLiveView.DeleteDatasetModal, visibility: @delete_dataset_modal_visibility, id: @dataset_id) %>

      <div phx-hook="showSnackbar">
        <%= if @save_success do %>
          <div id="snackbar" class="success-message"><%= @success_message %></div>
        <% end %>

        <%= if @has_validation_errors do %>
          <div id="snackbar" class="error-message">There were errors with the dataset you tried to submit</div>
        <% end %>

        <%= if @page_error do %>
          <div id="snackbar" class="error-message">A page error occurred</div>
        <% end %>
      </div>

    </div>
    """
  end

  def mount(_params, %{"dataset" => dataset}, socket) do
    new_changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)
    Process.flag(:trap_exit, true)

    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       changeset: new_changeset,
       dataset: dataset,
       dataset_id: dataset.id,
       has_validation_errors: false,
       new_field_initial_render: false,
       page_error: false,
       save_success: false,
       success_message: "",
       test_results: nil,
       finalize_form_data: nil,
       unsaved_changes: false,
       unsaved_changes_link: "/",
       unsaved_changes_modal_visibility: "hidden",
       publish_success_modal_visibility: "hidden",
       delete_dataset_modal_visibility: "hidden"
     )}
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "hidden")}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: socket.assigns.unsaved_changes_link)}
  end

  def handle_event("show-organizations", _, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: "/organizations", unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: "/organizations")}
    end
  end

  def handle_event("cancel-edit", _, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: "/", unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: "/")}
    end
  end

  def handle_event("dataset-delete", _, socket) do
    {:noreply, assign(socket, delete_dataset_modal_visibility: "visible")}
  end

  def handle_event("cancel-delete", _, socket) do
    {:noreply, assign(socket, delete_dataset_modal_visibility: "hidden")}
  end

  def handle_event("confirm-delete", %{"id" => id}, socket) do
    case DatasetStore.get(id) do
      {:ok, nil} ->
        Datasets.delete(id)
        {:noreply, redirect(socket, to: "/")}

      {:ok, smrt_dataset} ->
        Brook.Event.send(@instance_name, dataset_delete(), :andi, smrt_dataset)
        {:noreply, redirect(socket, to: "/")}
    end
  end

  def handle_event("reload-page", _, socket) do
    {:noreply, redirect(socket, to: "/datasets/#{socket.assigns.dataset.id}")}
  end

  def handle_info(:publish, socket) do
    socket = reset_save_success(socket)

    AndiWeb.Endpoint.broadcast("form-save", "save-all", %{dataset_id: socket.assigns.dataset_id})
    Process.sleep(1_000)

    andi_dataset = Datasets.get(socket.assigns.dataset.id)
    dataset_changeset = InputConverter.andi_dataset_to_full_ui_changeset(andi_dataset)

    if dataset_changeset.valid? do
      {:ok, smrt_dataset} = InputConverter.andi_dataset_to_smrt_dataset(andi_dataset)

      case Brook.Event.send(@instance_name, dataset_update(), :andi, smrt_dataset) do
        :ok ->
          {:noreply,
           assign(socket,
             dataset: andi_dataset,
             changeset: dataset_changeset,
             unsaved_changes: false,
             publish_success_modal_visibility: "visible",
             page_error: false
           )}

        error ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect(error)}")
      end
    else
      {:noreply, assign(socket, changeset: dataset_changeset, has_validation_errors: true)}
    end
  end

  def handle_info(
        %{topic: "form-save", payload: %{form_changeset: form_changeset, dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    socket = reset_save_success(socket)
    form_changes = InputConverter.form_changes_from_changeset(form_changeset)

    {:ok, andi_dataset} = Datasets.update_from_form(socket.assigns.dataset.id, form_changes)

    new_changeset =
      andi_dataset
      |> InputConverter.andi_dataset_to_full_ui_changeset()
      |> Dataset.validate_unique_system_name()
      |> Map.put(:action, :update)

    success_message =
      case new_changeset.valid? do
        true -> "Saved successfully."
        false -> "Saved successfully. You may need to fix errors before publishing."
      end

    {:noreply,
     assign(socket,
       save_success: true,
       success_message: success_message,
       changeset: new_changeset,
       unsaved_changes: false
     )}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(:cancel_edit, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: "/", unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: "/")}
    end
  end

  def handle_info(:form_update, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info(:page_error, socket) do
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, save_success: false)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp reset_save_success(socket), do: assign(socket, save_success: false, has_validation_errors: false)
end
