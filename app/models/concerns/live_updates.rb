# frozen_string_literal: true

# Concern for models that need real-time updates
#
# Automatically broadcasts model changes via ActionCable
# when records are created, updated, or destroyed
#
module LiveUpdates
  extend ActiveSupport::Concern

  included do
    after_create :broadcast_created, unless: :skip_live_updates?
    after_update :broadcast_updated, unless: :skip_live_updates?
    after_destroy :broadcast_destroyed, unless: :skip_live_updates?

    # Instance variable to control broadcasting
    attr_accessor :skip_live_updates
  end

  class_methods do
    # Configure which attributes should be included in broadcasts
    def live_update_attributes(*attrs)
      @live_update_attributes = attrs.flatten.map(&:to_sym)
    end

    def get_live_update_attributes
      @live_update_attributes || default_live_update_attributes
    end

    private

    def default_live_update_attributes
      # Safe default attributes
      column_names.map(&:to_sym) - [ :password_digest, :encrypted_password, :reset_password_token ]
    end
  end

  # Instance methods
  def skip_live_updates?
    skip_live_updates == true
  end

  def skip_live_updates!
    self.skip_live_updates = true
  end

  def as_live_update_json
    as_json(only: self.class.get_live_update_attributes)
  end

  def broadcast_update_now(action: :updated, user: nil)
    LiveUpdatesBroadcaster.broadcast_resource_update(
      self,
      action: action,
      changes: previous_changes,
      user: user
    )
  end

  def broadcast_to_users(users, data = {})
    Array(users).each do |user|
      LiveUpdatesBroadcaster.broadcast_user_update(user, {
        type: "resource_update",
        resource_type: self.class.name.underscore,
        resource_id: id,
        resource_data: as_live_update_json,
        **data
      })
    end
  end

  # Custom broadcast methods for specific scenarios
  def broadcast_status_change(old_status, new_status, user: nil)
    LiveUpdatesBroadcaster.broadcast_resource_update(
      self,
      action: :status_changed,
      changes: { status: [ old_status, new_status ] },
      user: user
    )
  end

  def broadcast_assignment_change(assignee, user: nil)
    LiveUpdatesBroadcaster.broadcast_resource_update(
      self,
      action: :assigned,
      changes: { assignee_id: assignee&.id },
      user: user
    )
  end

  def broadcast_progress_update(progress, user: nil)
    LiveUpdatesBroadcaster.broadcast_resource_update(
      self,
      action: :progress_updated,
      changes: { progress: progress },
      user: user
    )
  end

  private

  def broadcast_created
    current_user = find_current_user
    LiveUpdatesBroadcaster.broadcast_resource_created(self, user: current_user)
  end

  def broadcast_updated
    return unless saved_changes.any?

    current_user = find_current_user
    LiveUpdatesBroadcaster.broadcast_resource_update(
      self,
      action: :updated,
      changes: saved_changes,
      user: current_user
    )
  end

  def broadcast_destroyed
    current_user = find_current_user
    LiveUpdatesBroadcaster.broadcast_resource_deleted(self, user: current_user)
  end

  def find_current_user
    # Try to find current user from various sources
    if respond_to?(:paper_trail) && paper_trail.whodunnit
      User.find_by(id: paper_trail.whodunnit)
    elsif defined?(Current) && Current.respond_to?(:user)
      Current.user
    elsif Thread.current[:current_user]
      Thread.current[:current_user]
    end
  end
end
