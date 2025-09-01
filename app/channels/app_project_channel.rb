class AppProjectChannel < ApplicationCable::Channel
  def subscribed
    if params[:project_id].present?
      app_project = AppProject.find_by(id: params[:project_id])

      if app_project && (app_project.user_id == current_user.id || current_user.admin?)
        stream_from "app_project_#{params[:project_id]}"

        # Send initial status
        transmit({
          type: "connected",
          status: app_project.status,
          completion_percentage: app_project.completion_percentage
        })
      else
        reject
      end
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def request_status(data)
    app_project = AppProject.find_by(id: data["project_id"])

    if app_project && (app_project.user_id == current_user.id || current_user.admin?)
      transmit({
        type: "status_update",
        status: app_project.status,
        completion_percentage: app_project.completion_percentage,
        has_outputs: app_project.has_ai_outputs?,
        generation_metadata: app_project.generation_metadata
      })
    end
  end
end
