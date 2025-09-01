# frozen_string_literal: true

# Controller for demonstrating real-time features
#
class LiveDemoController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.recent.limit(10)
    @online_users_count = 0 # Will be updated by ActionCable
    @recent_activities = []
  end

  def send_notification
    notification = Notification.create!(
      user: current_user,
      sender: current_user,
      title: params[:title] || "Test Notification",
      message: params[:message] || "This is a test notification from the live demo.",
      notification_type: params[:type] || "info"
    )

    respond_to do |format|
      format.html { redirect_to live_demo_index_path, notice: "Notification sent!" }
      format.turbo_stream { head :ok }
      format.json { render json: { status: "success", notification_id: notification.id } }
    end
  end

  def send_system_announcement
    return unless current_user.system_admin?

    announcement = Notification.create_system_announcement(
      title: params[:title] || "System Announcement",
      message: params[:message] || "This is a system-wide announcement.",
      notification_type: "system",
      expires_at: 1.hour.from_now
    )

    respond_to do |format|
      format.html { redirect_to live_demo_index_path, notice: "System announcement sent!" }
      format.turbo_stream { head :ok }
      format.json { render json: { status: "success", announcement_count: announcement.count } }
    end
  end

  def broadcast_update
    # Simulate a resource update
    LiveUpdatesBroadcaster.broadcast_user_update(
      current_user,
      {
        type: "demo_update",
        message: params[:message] || "Demo update broadcast",
        timestamp: Time.current.iso8601
      }
    )

    respond_to do |format|
      format.html { redirect_to live_demo_index_path, notice: "Update broadcasted!" }
      format.turbo_stream { head :ok }
      format.json { render json: { status: "success" } }
    end
  end

  def start_progress_demo
    operation_id = SecureRandom.hex(8)

    # Start a background job that updates progress
    ProgressDemoJob.perform_later(current_user, operation_id)

    render json: { operation_id: operation_id, status: "started" }
  end
end
