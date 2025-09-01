# frozen_string_literal: true

# Job for processing Gmail messages
#
# Handles:
# - Processing incoming emails based on filters
# - Extracting attachments
# - Automated responses
# - Email forwarding and labeling
#
class GmailProcessorJob < GoogleWorkspaceJob
  # Process incoming emails based on configured filters
  #
  # @param filters [Hash] Email processing filters and actions
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform(filters, service_account_name: "email_processor", impersonate_user: nil)
    @gmail_service = GmailService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "gmail_processing_#{filters.keys.join('_')}"

    execute_with_progress(operation_name) do |progress|
      results = @gmail_service.process_incoming_emails(filters: filters)

      progress[:processed_count] = results[:processed].count
      progress[:error_count] = results[:errors].count
      progress[:filters_applied] = filters.keys

      Rails.logger.info "Gmail processing completed: #{results}"
      results
    end
  end

  # Extract attachments from specific emails
  #
  # @param message_ids [Array<String>] Gmail message IDs
  # @param save_path [String] Directory to save attachments
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_attachment_extraction(message_ids, save_path, service_account_name: "email_processor", impersonate_user: nil)
    @gmail_service = GmailService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "gmail_attachment_extraction"

    execute_with_progress(operation_name, message_ids.count) do |progress|
      extracted_attachments = []

      message_ids.each do |message_id|
        begin
          attachments = @gmail_service.get_attachments(message_id, save_path: save_path)

          extracted_attachments << {
            message_id: message_id,
            attachments: attachments,
            attachment_count: attachments.count
          }

          Rails.logger.info "Extracted #{attachments.count} attachments from message #{message_id}"
        rescue => error
          error_message = "Failed to extract attachments from message #{message_id}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        ensure
          update_progress(progress)
        end
      end

      progress[:extracted_attachments] = extracted_attachments
      progress[:total_attachments] = extracted_attachments.sum { |item| item[:attachment_count] }

      extracted_attachments
    end
  end

  # Send automated responses using templates
  #
  # @param template [String] Email template content
  # @param recipients [Array<String>] Recipient email addresses
  # @param template_data [Hash] Data for template interpolation
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_automated_responses(template, recipients, template_data: {}, service_account_name: "email_processor", impersonate_user: nil)
    @gmail_service = GmailService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "gmail_automated_responses"

    execute_with_progress(operation_name, recipients.count) do |progress|
      sent_messages = []

      recipients.each do |recipient|
        begin
          # Personalize template data for each recipient
          personalized_data = template_data.merge(recipient: recipient)

          sent_message = @gmail_service.send_automated_response(
            template: template,
            recipients: [ recipient ],
            data: personalized_data
          ).first

          sent_messages << {
            recipient: recipient,
            message_id: sent_message&.id,
            subject: personalized_data[:subject]
          }

          Rails.logger.info "Sent automated response to #{recipient}"
        rescue => error
          error_message = "Failed to send automated response to #{recipient}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        ensure
          update_progress(progress)
        end
      end

      progress[:sent_messages] = sent_messages
      progress[:success_count] = sent_messages.count { |msg| msg[:message_id].present? }

      sent_messages
    end
  end

  # Apply labels to messages based on criteria
  #
  # @param labeling_rules [Array<Hash>] Rules for applying labels
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_message_labeling(labeling_rules, service_account_name: "email_processor", impersonate_user: nil)
    @gmail_service = GmailService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "gmail_message_labeling"

    execute_with_progress(operation_name) do |progress|
      labeled_messages = []
      total_processed = 0

      labeling_rules.each do |rule|
        begin
          # Find messages matching the rule
          messages = @gmail_service.list_messages(
            query: rule[:query],
            max_results: rule[:max_results] || 100
          )

          progress[:total] += messages.count
          total_processed += messages.count

          messages.each do |message|
            begin
              @gmail_service.add_label(message.id, rule[:label_name])

              labeled_messages << {
                message_id: message.id,
                label_applied: rule[:label_name],
                rule: rule[:name]
              }

              Rails.logger.debug "Applied label '#{rule[:label_name]}' to message #{message.id}"
            rescue => error
              error_message = "Failed to label message #{message.id}: #{error.message}"
              add_error(progress, error_message)
              Rails.logger.error error_message
            ensure
              update_progress(progress)
            end
          end
        rescue => error
          error_message = "Failed to process labeling rule '#{rule[:name]}': #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        end
      end

      progress[:labeled_messages] = labeled_messages
      progress[:rules_processed] = labeling_rules.count
      progress[:total_processed] = total_processed

      labeled_messages
    end
  end

  # Monitor inbox for new messages and trigger processing
  #
  # @param monitoring_config [Hash] Monitoring configuration
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_inbox_monitoring(monitoring_config, service_account_name: "email_processor", impersonate_user: nil)
    @gmail_service = GmailService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "gmail_inbox_monitoring"

    execute_with_progress(operation_name) do |progress|
      # Get the last processed message timestamp
      last_processed = monitoring_config[:last_processed] || 1.hour.ago

      # Query for new messages since last processing
      query = "after:#{last_processed.to_i}"
      query += " #{monitoring_config[:additional_query]}" if monitoring_config[:additional_query]

      new_messages = @gmail_service.list_messages(
        query: query,
        max_results: monitoring_config[:max_messages] || 50
      )

      progress[:total] = new_messages.count
      progress[:new_messages_found] = new_messages.count

      processed_messages = []

      new_messages.each do |message|
        begin
          # Get full message details
          full_message = @gmail_service.get_message(message.id)

          # Apply configured actions
          if monitoring_config[:actions]
            monitoring_config[:actions].each do |action|
              case action[:type]
              when "extract_attachments"
                if action[:save_path]
                  attachments = @gmail_service.get_attachments(message.id, save_path: action[:save_path])
                  full_message.extracted_attachments = attachments
                end
              when "add_label"
                if action[:label_name]
                  @gmail_service.add_label(message.id, action[:label_name])
                end
              when "mark_as_read"
                @gmail_service.mark_as_read(message.id)
              end
            end
          end

          processed_messages << {
            message_id: message.id,
            subject: extract_subject(full_message),
            from: extract_sender(full_message),
            received_at: extract_date(full_message)
          }

          Rails.logger.info "Processed new message: #{message.id}"
        rescue => error
          error_message = "Failed to process message #{message.id}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        ensure
          update_progress(progress)
        end
      end

      progress[:processed_messages] = processed_messages
      progress[:last_processed_at] = Time.current

      processed_messages
    end
  end

  private

  # Extract subject from message
  def extract_subject(message)
    header = message.payload.headers.find { |h| h.name == "Subject" }
    header&.value || "No Subject"
  end

  # Extract sender from message
  def extract_sender(message)
    header = message.payload.headers.find { |h| h.name == "From" }
    header&.value || "Unknown Sender"
  end

  # Extract date from message
  def extract_date(message)
    header = message.payload.headers.find { |h| h.name == "Date" }
    Time.parse(header.value) if header&.value
  rescue
    Time.current
  end
end
