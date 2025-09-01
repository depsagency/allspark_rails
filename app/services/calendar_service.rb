# frozen_string_literal: true

# Google Calendar API Service
#
# Provides methods for interacting with Google Calendar API including:
# - Event creation and management
# - Calendar operations
# - Meeting scheduling
# - Availability checking
#
class CalendarService
  include GoogleWorkspaceIntegration

  REQUIRED_SCOPES = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/calendar.events"
  ].freeze

  def initialize(service_account_name: "calendar_agent", impersonate_user: nil)
    @calendar_service = setup_calendar_client(service_account_name, impersonate_user)
  end

  # List events from a calendar
  #
  # @param calendar_id [String] Calendar ID ('primary' for main calendar)
  # @param time_min [Time, nil] Start time filter
  # @param time_max [Time, nil] End time filter
  # @param max_results [Integer] Maximum number of events
  # @return [Array<Google::Apis::CalendarV3::Event>] Array of events
  def list_events(calendar_id: "primary", time_min: nil, time_max: nil, max_results: 100)
    execute_with_retry("list_events:#{calendar_id}") do
      response = @calendar_service.list_events(
        calendar_id,
        max_results: max_results,
        single_events: true,
        order_by: "startTime",
        time_min: time_min&.iso8601,
        time_max: time_max&.iso8601
      )

      response.items || []
    end
  end

  # Create a new event
  #
  # @param summary [String] Event title
  # @param start_time [Time] Event start time
  # @param end_time [Time] Event end time
  # @param attendees [Array<String>] Attendee email addresses
  # @param description [String, nil] Event description
  # @param location [String, nil] Event location
  # @param calendar_id [String] Calendar ID to create event in
  # @return [Google::Apis::CalendarV3::Event] Created event
  def create_event(summary:, start_time:, end_time:, attendees: [], description: nil, location: nil, calendar_id: "primary")
    event = Google::Apis::CalendarV3::Event.new(
      summary: summary,
      description: description,
      location: location,
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: Time.zone.name
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: Time.zone.name
      ),
      attendees: attendees.map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) }
    )

    execute_with_retry("create_event:#{summary}") do
      @calendar_service.insert_event(calendar_id, event, send_notifications: true)
    end
  end

  # Update an existing event
  #
  # @param event_id [String] Event ID to update
  # @param updates [Hash] Hash of updates to apply
  # @param calendar_id [String] Calendar ID
  # @return [Google::Apis::CalendarV3::Event] Updated event
  def update_event(event_id, updates, calendar_id: "primary")
    # Get current event
    current_event = get_event(event_id, calendar_id: calendar_id)

    # Apply updates
    updates.each do |key, value|
      case key.to_s
      when "summary"
        current_event.summary = value
      when "description"
        current_event.description = value
      when "location"
        current_event.location = value
      when "start_time"
        current_event.start = Google::Apis::CalendarV3::EventDateTime.new(
          date_time: value.iso8601,
          time_zone: Time.zone.name
        )
      when "end_time"
        current_event.end = Google::Apis::CalendarV3::EventDateTime.new(
          date_time: value.iso8601,
          time_zone: Time.zone.name
        )
      when "attendees"
        current_event.attendees = Array(value).map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) }
      end
    end

    execute_with_retry("update_event:#{event_id}") do
      @calendar_service.update_event(calendar_id, event_id, current_event, send_notifications: true)
    end
  end

  # Delete an event
  #
  # @param event_id [String] Event ID to delete
  # @param calendar_id [String] Calendar ID
  # @return [void]
  def delete_event(event_id, calendar_id: "primary")
    execute_with_retry("delete_event:#{event_id}") do
      @calendar_service.delete_event(calendar_id, event_id, send_notifications: true)
    end
  end

  # Get event details
  #
  # @param event_id [String] Event ID
  # @param calendar_id [String] Calendar ID
  # @return [Google::Apis::CalendarV3::Event] Event details
  def get_event(event_id, calendar_id: "primary")
    execute_with_retry("get_event:#{event_id}") do
      @calendar_service.get_event(calendar_id, event_id)
    end
  end

  # Get busy times for calendars
  #
  # @param time_min [Time] Start time
  # @param time_max [Time] End time
  # @param calendars [Array<String>] Calendar IDs to check
  # @return [Hash] Busy times by calendar
  def get_busy_times(time_min, time_max, calendars: [ "primary" ])
    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: time_min.iso8601,
      time_max: time_max.iso8601,
      items: calendars.map { |cal| Google::Apis::CalendarV3::FreeBusyRequestItem.new(id: cal) }
    )

    execute_with_retry("get_busy_times") do
      response = @calendar_service.query_freebusy(request)

      busy_times = {}
      response.calendars.each do |calendar_id, calendar_data|
        busy_times[calendar_id] = calendar_data.busy.map do |busy_period|
          {
            start: Time.parse(busy_period.start),
            end: Time.parse(busy_period.end)
          }
        end
      end

      busy_times
    end
  end

  # Add attendee to existing event
  #
  # @param event_id [String] Event ID
  # @param email [String] Attendee email
  # @param calendar_id [String] Calendar ID
  # @return [Google::Apis::CalendarV3::Event] Updated event
  def add_attendee(event_id, email, calendar_id: "primary")
    event = get_event(event_id, calendar_id: calendar_id)

    # Check if attendee already exists
    existing_attendee = event.attendees&.find { |attendee| attendee.email == email }
    return event if existing_attendee

    # Add new attendee
    event.attendees ||= []
    event.attendees << Google::Apis::CalendarV3::EventAttendee.new(email: email)

    execute_with_retry("add_attendee:#{event_id}:#{email}") do
      @calendar_service.update_event(calendar_id, event_id, event, send_notifications: true)
    end
  end

  # Create recurring event
  #
  # @param summary [String] Event title
  # @param start_time [Time] Event start time
  # @param end_time [Time] Event end time
  # @param recurrence_rule [String] RRULE string (e.g., "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR")
  # @param attendees [Array<String>] Attendee email addresses
  # @param calendar_id [String] Calendar ID
  # @return [Google::Apis::CalendarV3::Event] Created recurring event
  def create_recurring_event(summary:, start_time:, end_time:, recurrence_rule:, attendees: [], calendar_id: "primary")
    event = Google::Apis::CalendarV3::Event.new(
      summary: summary,
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: Time.zone.name
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: Time.zone.name
      ),
      attendees: attendees.map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) },
      recurrence: [ recurrence_rule ]
    )

    execute_with_retry("create_recurring_event:#{summary}") do
      @calendar_service.insert_event(calendar_id, event, send_notifications: true)
    end
  end

  # Schedule meeting with availability checking
  #
  # @param attendees [Array<String>] Required attendee emails
  # @param duration [Integer] Duration in minutes
  # @param preferences [Hash] Scheduling preferences
  # @return [Google::Apis::CalendarV3::Event, nil] Scheduled event or nil if no time found
  def schedule_meeting(attendees:, duration:, preferences: {})
    start_date = preferences[:start_date] || Date.current
    end_date = preferences[:end_date] || (start_date + 7.days)
    business_hours = preferences[:business_hours] || { start: 9, end: 17 }

    # Find available time slot
    available_slot = find_available_slot(
      attendees: attendees,
      duration: duration,
      start_date: start_date,
      end_date: end_date,
      business_hours: business_hours
    )

    return nil unless available_slot

    # Create the meeting
    create_event(
      summary: preferences[:title] || "Scheduled Meeting",
      start_time: available_slot[:start],
      end_time: available_slot[:end],
      attendees: attendees,
      description: preferences[:description],
      location: preferences[:location]
    )
  end

  # Sync external calendar
  #
  # @param external_calendar_id [String] External calendar ID
  # @param local_calendar_id [String] Local calendar ID
  # @return [Hash] Sync results
  def sync_external_calendars(external_calendar_id, local_calendar_id: "primary")
    results = { imported: [], errors: [] }

    # Get events from external calendar
    external_events = list_events(calendar_id: external_calendar_id)

    external_events.each do |event|
      begin
        # Create event in local calendar
        created_event = create_event(
          summary: event.summary,
          start_time: Time.parse(event.start.date_time || event.start.date),
          end_time: Time.parse(event.end.date_time || event.end.date),
          attendees: event.attendees&.map(&:email) || [],
          description: event.description,
          location: event.location,
          calendar_id: local_calendar_id
        )

        results[:imported] << { external_id: event.id, local_id: created_event.id }
      rescue => e
        results[:errors] << { event_id: event.id, error: e.message }
      end
    end

    results
  end

  # Generate meeting insights
  #
  # @param start_date [Date] Analysis start date
  # @param end_date [Date] Analysis end date
  # @param calendar_id [String] Calendar ID to analyze
  # @return [Hash] Meeting insights and analytics
  def meeting_insights(start_date: 30.days.ago.to_date, end_date: Date.current, calendar_id: "primary")
    events = list_events(
      calendar_id: calendar_id,
      time_min: start_date.beginning_of_day,
      time_max: end_date.end_of_day
    )

    # Filter out all-day events and focus on meetings
    meetings = events.select do |event|
      event.start.date_time.present? &&
      event.attendees&.length.to_i > 1
    end

    {
      total_meetings: meetings.count,
      total_meeting_hours: calculate_total_hours(meetings),
      average_meeting_duration: calculate_average_duration(meetings),
      meetings_by_day: group_meetings_by_day(meetings),
      busiest_day: find_busiest_day(meetings),
      meeting_patterns: analyze_meeting_patterns(meetings),
      attendee_frequency: analyze_attendee_frequency(meetings)
    }
  end

  private

  # Setup Calendar API client
  def setup_calendar_client(service_account_name, impersonate_user)
    authorizer = setup_google_auth(service_account_name, impersonate_user, REQUIRED_SCOPES)

    Google::Apis::CalendarV3::CalendarService.new.tap do |service|
      service.authorization = authorizer
    end
  end

  # Test API access by getting calendar list
  def test_api_access
    execute_with_retry("test_connection") do
      @calendar_service.list_calendar_lists(max_results: 1)
    end
  end

  # Find available time slot for meeting
  def find_available_slot(attendees:, duration:, start_date:, end_date:, business_hours:)
    current_date = start_date

    while current_date <= end_date
      # Skip weekends unless specified
      unless current_date.saturday? || current_date.sunday?
        slot = find_slot_on_date(
          attendees: attendees,
          duration: duration,
          date: current_date,
          business_hours: business_hours
        )

        return slot if slot
      end

      current_date += 1.day
    end

    nil
  end

  # Find available slot on a specific date
  def find_slot_on_date(attendees:, duration:, date:, business_hours:)
    start_time = date.beginning_of_day + business_hours[:start].hours
    end_time = date.beginning_of_day + business_hours[:end].hours

    # Get busy times for all attendees
    busy_times = get_busy_times(start_time, end_time, calendars: attendees)

    # Merge all busy periods
    all_busy_periods = []
    busy_times.each do |calendar_id, periods|
      all_busy_periods.concat(periods)
    end

    # Sort busy periods by start time
    all_busy_periods.sort_by! { |period| period[:start] }

    # Find gaps
    current_time = start_time

    all_busy_periods.each do |busy_period|
      gap_duration = busy_period[:start] - current_time

      if gap_duration >= duration.minutes
        return {
          start: current_time,
          end: current_time + duration.minutes
        }
      end

      current_time = [ current_time, busy_period[:end] ].max
    end

    # Check final gap until end of business hours
    final_gap = end_time - current_time
    if final_gap >= duration.minutes
      return {
        start: current_time,
        end: current_time + duration.minutes
      }
    end

    nil
  end

  # Calculate total meeting hours
  def calculate_total_hours(meetings)
    total_minutes = meetings.sum do |meeting|
      start_time = Time.parse(meeting.start.date_time)
      end_time = Time.parse(meeting.end.date_time)
      ((end_time - start_time) / 60).round
    end

    (total_minutes / 60.0).round(2)
  end

  # Calculate average meeting duration
  def calculate_average_duration(meetings)
    return 0 if meetings.empty?

    total_minutes = meetings.sum do |meeting|
      start_time = Time.parse(meeting.start.date_time)
      end_time = Time.parse(meeting.end.date_time)
      ((end_time - start_time) / 60).round
    end

    (total_minutes / meetings.count).round
  end

  # Group meetings by day of week
  def group_meetings_by_day(meetings)
    meetings.group_by do |meeting|
      Time.parse(meeting.start.date_time).strftime("%A")
    end.transform_values(&:count)
  end

  # Find busiest day
  def find_busiest_day(meetings)
    day_counts = group_meetings_by_day(meetings)
    day_counts.max_by { |day, count| count }&.first
  end

  # Analyze meeting patterns
  def analyze_meeting_patterns(meetings)
    hour_distribution = meetings.group_by do |meeting|
      Time.parse(meeting.start.date_time).hour
    end.transform_values(&:count)

    {
      peak_hours: hour_distribution.sort_by { |hour, count| -count }.first(3),
      hour_distribution: hour_distribution
    }
  end

  # Analyze attendee frequency
  def analyze_attendee_frequency(meetings)
    attendee_counts = Hash.new(0)

    meetings.each do |meeting|
      next unless meeting.attendees

      meeting.attendees.each do |attendee|
        attendee_counts[attendee.email] += 1 if attendee.email
      end
    end

    attendee_counts.sort_by { |email, count| -count }.first(10).to_h
  end
end
