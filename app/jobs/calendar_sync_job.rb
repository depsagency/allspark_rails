# frozen_string_literal: true

# Job for syncing and managing Google Calendar events
#
# Handles:
# - Syncing events between calendars
# - Bulk event creation
# - Meeting scheduling
# - Calendar analytics
#
class CalendarSyncJob < GoogleWorkspaceJob
  # Sync events between two calendars
  #
  # @param source_calendar_id [String] Source calendar ID
  # @param target_calendar_id [String] Target calendar ID
  # @param sync_period [Hash] Time period to sync (:start_date, :end_date)
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform(source_calendar_id, target_calendar_id, sync_period: {}, service_account_name: "calendar_agent", impersonate_user: nil)
    @calendar_service = CalendarService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "calendar_sync_#{source_calendar_id}_to_#{target_calendar_id}"

    execute_with_progress(operation_name) do |progress|
      start_date = sync_period[:start_date] || 1.week.ago
      end_date = sync_period[:end_date] || 1.week.from_now

      sync_results = @calendar_service.sync_external_calendars(
        source_calendar_id,
        local_calendar_id: target_calendar_id
      )

      progress[:sync_results] = sync_results
      progress[:imported_count] = sync_results[:imported].count
      progress[:error_count] = sync_results[:errors].count

      Rails.logger.info "Calendar sync completed: #{sync_results}"
      sync_results
    end
  end

  # Create multiple events in bulk
  #
  # @param events_data [Array<Hash>] Array of event data
  # @param calendar_id [String] Calendar to create events in
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_bulk_creation(events_data, calendar_id: "primary", service_account_name: "calendar_agent", impersonate_user: nil)
    @calendar_service = CalendarService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "calendar_bulk_creation"

    execute_with_progress(operation_name, events_data.count) do |progress|
      created_events = []

      events_data.each do |event_data|
        begin
          created_event = @calendar_service.create_event(
            summary: event_data[:summary],
            start_time: Time.parse(event_data[:start_time]),
            end_time: Time.parse(event_data[:end_time]),
            attendees: event_data[:attendees] || [],
            description: event_data[:description],
            location: event_data[:location],
            calendar_id: calendar_id
          )

          created_events << {
            event_id: created_event.id,
            summary: created_event.summary,
            start_time: created_event.start.date_time,
            html_link: created_event.html_link
          }

          Rails.logger.info "Created event: #{created_event.summary} (#{created_event.id})"
        rescue => error
          error_message = "Failed to create event '#{event_data[:summary]}': #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        ensure
          update_progress(progress)
        end
      end

      progress[:created_events] = created_events
      progress[:success_count] = created_events.count

      created_events
    end
  end

  # Schedule meetings with availability checking
  #
  # @param meeting_requests [Array<Hash>] Array of meeting requests
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_meeting_scheduling(meeting_requests, service_account_name: "calendar_agent", impersonate_user: nil)
    @calendar_service = CalendarService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "calendar_meeting_scheduling"

    execute_with_progress(operation_name, meeting_requests.count) do |progress|
      scheduled_meetings = []

      meeting_requests.each do |request|
        begin
          scheduled_event = @calendar_service.schedule_meeting(
            attendees: request[:attendees],
            duration: request[:duration],
            preferences: request[:preferences] || {}
          )

          if scheduled_event
            scheduled_meetings << {
              request_id: request[:id],
              event_id: scheduled_event.id,
              summary: scheduled_event.summary,
              start_time: scheduled_event.start.date_time,
              end_time: scheduled_event.end.date_time,
              attendees: request[:attendees],
              status: "scheduled"
            }

            Rails.logger.info "Scheduled meeting: #{scheduled_event.summary} at #{scheduled_event.start.date_time}"
          else
            error_message = "No available time slot found for meeting request #{request[:id]}"
            add_error(progress, error_message)

            scheduled_meetings << {
              request_id: request[:id],
              status: "failed",
              reason: "No available time slot"
            }

            Rails.logger.warn error_message
          end
        rescue => error
          error_message = "Failed to schedule meeting request #{request[:id]}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message

          scheduled_meetings << {
            request_id: request[:id],
            status: "error",
            reason: error.message
          }
        ensure
          update_progress(progress)
        end
      end

      progress[:scheduled_meetings] = scheduled_meetings
      progress[:success_count] = scheduled_meetings.count { |m| m[:status] == "scheduled" }
      progress[:failed_count] = scheduled_meetings.count { |m| m[:status] != "scheduled" }

      scheduled_meetings
    end
  end

  # Generate calendar analytics and insights
  #
  # @param analysis_config [Hash] Analysis configuration
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_analytics_generation(analysis_config, service_account_name: "calendar_agent", impersonate_user: nil)
    @calendar_service = CalendarService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "calendar_analytics"

    execute_with_progress(operation_name) do |progress|
      start_date = analysis_config[:start_date] || 30.days.ago.to_date
      end_date = analysis_config[:end_date] || Date.current
      calendars = analysis_config[:calendars] || [ "primary" ]

      analytics_results = {}

      calendars.each do |calendar_id|
        begin
          insights = @calendar_service.meeting_insights(
            start_date: start_date,
            end_date: end_date,
            calendar_id: calendar_id
          )

          analytics_results[calendar_id] = insights

          Rails.logger.info "Generated analytics for calendar #{calendar_id}: #{insights[:total_meetings]} meetings"
        rescue => error
          error_message = "Failed to generate analytics for calendar #{calendar_id}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        end
      end

      # Generate summary across all calendars
      if analytics_results.any?
        summary = generate_summary_analytics(analytics_results)
        analytics_results[:summary] = summary
      end

      progress[:analytics_results] = analytics_results
      progress[:calendars_analyzed] = calendars.count
      progress[:date_range] = { start: start_date, end: end_date }

      analytics_results
    end
  end

  # Update recurring events based on rules
  #
  # @param update_rules [Array<Hash>] Rules for updating events
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_recurring_updates(update_rules, service_account_name: "calendar_agent", impersonate_user: nil)
    @calendar_service = CalendarService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "calendar_recurring_updates"

    execute_with_progress(operation_name) do |progress|
      updated_events = []

      update_rules.each do |rule|
        begin
          # Find events matching the rule criteria
          events = @calendar_service.list_events(
            calendar_id: rule[:calendar_id] || "primary",
            time_min: rule[:time_min],
            time_max: rule[:time_max]
          )

          # Filter events based on rule criteria
          matching_events = events.select do |event|
            matches_rule?(event, rule[:criteria])
          end

          progress[:total] += matching_events.count

          matching_events.each do |event|
            begin
              @calendar_service.update_event(
                event.id,
                rule[:updates],
                calendar_id: rule[:calendar_id] || "primary"
              )

              updated_events << {
                event_id: event.id,
                summary: event.summary,
                updates_applied: rule[:updates].keys,
                rule_name: rule[:name]
              }

              Rails.logger.info "Updated event #{event.id} with rule '#{rule[:name]}'"
            rescue => error
              error_message = "Failed to update event #{event.id}: #{error.message}"
              add_error(progress, error_message)
              Rails.logger.error error_message
            ensure
              update_progress(progress)
            end
          end
        rescue => error
          error_message = "Failed to process update rule '#{rule[:name]}': #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        end
      end

      progress[:updated_events] = updated_events
      progress[:rules_processed] = update_rules.count

      updated_events
    end
  end

  private

  # Check if event matches rule criteria
  def matches_rule?(event, criteria)
    return true if criteria.blank?

    criteria.all? do |key, value|
      case key.to_s
      when "summary_contains"
        event.summary&.include?(value)
      when "location_contains"
        event.location&.include?(value)
      when "has_attendees"
        value ? event.attendees&.any? : event.attendees&.empty?
      when "duration_minutes"
        event_duration = calculate_event_duration(event)
        case value
        when Hash
          (value[:min].nil? || event_duration >= value[:min]) &&
          (value[:max].nil? || event_duration <= value[:max])
        else
          event_duration == value
        end
      else
        true
      end
    end
  end

  # Calculate event duration in minutes
  def calculate_event_duration(event)
    return 0 unless event.start&.date_time && event.end&.date_time

    start_time = Time.parse(event.start.date_time)
    end_time = Time.parse(event.end.date_time)
    ((end_time - start_time) / 60).round
  end

  # Generate summary analytics across all calendars
  def generate_summary_analytics(analytics_results)
    total_meetings = analytics_results.values.sum { |r| r[:total_meetings] || 0 }
    total_hours = analytics_results.values.sum { |r| r[:total_meeting_hours] || 0 }

    # Merge attendee frequencies
    all_attendees = {}
    analytics_results.each do |calendar_id, results|
      next unless results[:attendee_frequency]

      results[:attendee_frequency].each do |email, count|
        all_attendees[email] = (all_attendees[email] || 0) + count
      end
    end

    # Find most common meeting patterns
    all_patterns = {}
    analytics_results.each do |calendar_id, results|
      next unless results[:meeting_patterns]&.dig(:hour_distribution)

      results[:meeting_patterns][:hour_distribution].each do |hour, count|
        all_patterns[hour] = (all_patterns[hour] || 0) + count
      end
    end

    {
      total_meetings_across_calendars: total_meetings,
      total_meeting_hours: total_hours.round(2),
      average_meetings_per_calendar: (total_meetings.to_f / analytics_results.count).round(2),
      top_attendees: all_attendees.sort_by { |email, count| -count }.first(10).to_h,
      peak_meeting_hours: all_patterns.sort_by { |hour, count| -count }.first(5).to_h,
      calendars_analyzed: analytics_results.keys.reject { |k| k == :summary }
    }
  end
end
