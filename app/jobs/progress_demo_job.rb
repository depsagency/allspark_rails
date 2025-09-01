# frozen_string_literal: true

# Demo job for showing live progress updates
#
class ProgressDemoJob < ApplicationJob
  queue_as :default

  def perform(user, operation_id)
    (0..100).step(10) do |progress|
      LiveUpdatesBroadcaster.broadcast_progress_update(
        user: user,
        operation_id: operation_id,
        progress: progress,
        message: "Processing step #{progress/10 + 1} of 11..."
      )

      sleep(0.5) # Simulate work
    end

    # Final completion message
    LiveUpdatesBroadcaster.broadcast_progress_update(
      user: user,
      operation_id: operation_id,
      progress: 100,
      message: "Operation completed successfully!"
    )
  end
end
