# frozen_string_literal: true

class McpAuditLogCleanupJob < ApplicationJob
  queue_as :maintenance

  # Run cleanup monthly by default
  CLEANUP_FREQUENCY = 1.month

  def perform(retention_days: 90, batch_size: 1000)
    Rails.logger.info "[MCP Cleanup] Starting audit log cleanup with #{retention_days} day retention"
    
    cutoff_date = retention_days.days.ago
    total_deleted = 0
    
    # Delete in batches to avoid long-running transactions
    loop do
      deleted_count = McpAuditLog.where('executed_at < ?', cutoff_date)
                                 .limit(batch_size)
                                 .delete_all
      
      total_deleted += deleted_count
      
      break if deleted_count == 0
      
      # Brief pause between batches to avoid overwhelming the database
      sleep(0.1) if deleted_count == batch_size
    end
    
    Rails.logger.info "[MCP Cleanup] Deleted #{total_deleted} audit log records older than #{retention_days} days"
    
    # Update cleanup statistics
    update_cleanup_stats(total_deleted, retention_days)
    
    # Schedule next cleanup
    schedule_next_cleanup(retention_days, batch_size)
  end

  private

  def update_cleanup_stats(deleted_count, retention_days)
    Rails.cache.write('mcp_last_cleanup', {
      timestamp: Time.current,
      deleted_count: deleted_count,
      retention_days: retention_days,
      total_remaining: McpAuditLog.count
    }, expires_in: 1.year)
  end

  def schedule_next_cleanup(retention_days, batch_size)
    McpAuditLogCleanupJob.set(wait: CLEANUP_FREQUENCY)
                         .perform_later(retention_days: retention_days, batch_size: batch_size)
  end

  # Class method to start the cleanup cycle
  def self.start_cleanup_cycle(retention_days: 90, batch_size: 1000)
    # Cancel any existing cleanup jobs
    Sidekiq::ScheduledSet.new.each do |job|
      job.delete if job.klass == 'McpAuditLogCleanupJob'
    end
    
    # Schedule the first cleanup
    perform_later(retention_days: retention_days, batch_size: batch_size)
  end

  # Class method to get cleanup statistics
  def self.cleanup_stats
    Rails.cache.read('mcp_last_cleanup') || {
      timestamp: nil,
      deleted_count: 0,
      retention_days: 90,
      total_remaining: McpAuditLog.count
    }
  end
end