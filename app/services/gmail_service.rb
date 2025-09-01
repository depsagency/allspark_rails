# frozen_string_literal: true

# Gmail API Service
#
# Provides methods for interacting with Gmail API including:
# - Message listing and retrieval
# - Sending emails
# - Label management
# - Attachment handling
# - Filter management
#
class GmailService
  include GoogleWorkspaceIntegration

  REQUIRED_SCOPES = [
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.settings.basic"
  ].freeze

  def initialize(service_account_name: "email_processor", impersonate_user: nil)
    @gmail_service = setup_gmail_client(service_account_name, impersonate_user)
  end

  # List messages from Gmail
  #
  # @param query [String, nil] Gmail search query
  # @param label_ids [Array<String>] Label IDs to filter by
  # @param max_results [Integer] Maximum number of messages to return
  # @return [Array<Google::Apis::GmailV1::Message>] Array of messages
  def list_messages(query: nil, label_ids: [], max_results: 100)
    execute_with_retry("list_messages") do
      response = @gmail_service.list_user_messages(
        "me",
        q: query,
        label_ids: label_ids,
        max_results: max_results
      )

      response.messages || []
    end
  end

  # Get a specific message
  #
  # @param message_id [String] Message ID
  # @param format [String] Message format ('full', 'metadata', 'minimal')
  # @return [Google::Apis::GmailV1::Message] Message object
  def get_message(message_id, format: "full")
    execute_with_retry("get_message:#{message_id}") do
      @gmail_service.get_user_message("me", message_id, format: format)
    end
  end

  # Send an email
  #
  # @param to [String, Array<String>] Recipient email(s)
  # @param subject [String] Email subject
  # @param body [String] Email body (HTML or plain text)
  # @param attachments [Array<Hash>] Attachments with :path and :name keys
  # @param from [String, nil] Sender email (defaults to impersonated user)
  # @return [Google::Apis::GmailV1::Message] Sent message
  def send_message(to:, subject:, body:, attachments: [], from: nil)
    recipients = Array(to)
    sender = from || impersonate_user

    message = build_email_message(sender, recipients, subject, body, attachments)

    execute_with_retry("send_message:#{subject}") do
      @gmail_service.send_user_message("me", message)
    end
  end

  # Create a draft email
  #
  # @param to [String, Array<String>] Recipient email(s)
  # @param subject [String] Email subject
  # @param body [String] Email body
  # @return [Google::Apis::GmailV1::Draft] Created draft
  def create_draft(to:, subject:, body:)
    recipients = Array(to)
    sender = impersonate_user

    message = build_email_message(sender, recipients, subject, body, [])
    draft = Google::Apis::GmailV1::Draft.new(message: message)

    execute_with_retry("create_draft:#{subject}") do
      @gmail_service.create_user_draft("me", draft)
    end
  end

  # Add label to a message
  #
  # @param message_id [String] Message ID
  # @param label_name [String] Label name to add
  # @return [Google::Apis::GmailV1::Message] Updated message
  def add_label(message_id, label_name)
    label_id = find_or_create_label(label_name)

    modify_request = Google::Apis::GmailV1::ModifyMessageRequest.new(
      add_label_ids: [ label_id ]
    )

    execute_with_retry("add_label:#{message_id}:#{label_name}") do
      @gmail_service.modify_message("me", message_id, modify_request)
    end
  end

  # Mark message as read
  #
  # @param message_id [String] Message ID
  # @return [Google::Apis::GmailV1::Message] Updated message
  def mark_as_read(message_id)
    modify_request = Google::Apis::GmailV1::ModifyMessageRequest.new(
      remove_label_ids: [ "UNREAD" ]
    )

    execute_with_retry("mark_as_read:#{message_id}") do
      @gmail_service.modify_message("me", message_id, modify_request)
    end
  end

  # Get attachments from a message
  #
  # @param message_id [String] Message ID
  # @param save_path [String, nil] Directory to save attachments (optional)
  # @return [Array<Hash>] Array of attachment info
  def get_attachments(message_id, save_path: nil)
    message = get_message(message_id)
    attachments = []

    extract_attachments_from_parts(message.payload, message_id, save_path, attachments)

    attachments
  end

  # Create Gmail filter
  #
  # @param criteria [Hash] Filter criteria
  # @param actions [Hash] Filter actions
  # @return [Google::Apis::GmailV1::Filter] Created filter
  def create_filter(criteria:, actions:)
    filter_criteria = Google::Apis::GmailV1::FilterCriteria.new(criteria)
    filter_action = Google::Apis::GmailV1::FilterAction.new(actions)

    filter = Google::Apis::GmailV1::Filter.new(
      criteria: filter_criteria,
      action: filter_action
    )

    execute_with_retry("create_filter") do
      @gmail_service.create_user_setting_filter("me", filter)
    end
  end

  # Process incoming emails based on filters
  #
  # @param filters [Hash] Processing filters and actions
  # @return [Hash] Processing results
  def process_incoming_emails(filters: {})
    results = { processed: [], errors: [] }

    filters.each do |filter_name, config|
      begin
        messages = list_messages(
          query: config[:query],
          label_ids: config[:label_ids],
          max_results: config[:max_results] || 50
        )

        messages.each do |message_summary|
          begin
            full_message = get_message(message_summary.id)
            process_message(full_message, config[:actions] || {})
            results[:processed] << { filter: filter_name, message_id: message_summary.id }
          rescue => e
            results[:errors] << { filter: filter_name, message_id: message_summary.id, error: e.message }
          end
        end
      rescue => e
        results[:errors] << { filter: filter_name, error: e.message }
      end
    end

    results
  end

  # Send automated response using template
  #
  # @param template [String] Email template name or content
  # @param recipients [Array<String>] Recipient emails
  # @param data [Hash] Template data for interpolation
  # @return [Array<Google::Apis::GmailV1::Message>] Sent messages
  def send_automated_response(template:, recipients:, data: {})
    sent_messages = []

    recipients.each do |recipient|
      begin
        body = render_email_template(template, data.merge(recipient: recipient))
        subject = data[:subject] || "Automated Response"

        message = send_message(
          to: recipient,
          subject: subject,
          body: body
        )

        sent_messages << message
      rescue => e
        Rails.logger.error "Failed to send automated response to #{recipient}: #{e.message}"
      end
    end

    sent_messages
  end

  private

  # Setup Gmail API client
  def setup_gmail_client(service_account_name, impersonate_user)
    authorizer = setup_google_auth(service_account_name, impersonate_user, REQUIRED_SCOPES)

    Google::Apis::GmailV1::GmailService.new.tap do |service|
      service.authorization = authorizer
    end
  end

  # Test API access by getting user profile
  def test_api_access
    execute_with_retry("test_connection") do
      @gmail_service.get_user_profile("me")
    end
  end

  # Build email message for sending
  def build_email_message(from, to, subject, body, attachments)
    mail = Mail.new
    mail.from = from
    mail.to = to
    mail.subject = subject

    if body.include?("<html>") || body.include?("<")
      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body body
      end
    else
      mail.text_part = Mail::Part.new do
        content_type "text/plain; charset=UTF-8"
        body body
      end
    end

    # Add attachments
    attachments.each do |attachment|
      mail.add_file(attachment[:path]) if File.exist?(attachment[:path])
    end

    Google::Apis::GmailV1::Message.new(raw: Base64.urlsafe_encode64(mail.to_s))
  end

  # Find or create a label
  def find_or_create_label(label_name)
    labels = @gmail_service.list_user_labels("me")
    existing_label = labels.labels&.find { |label| label.name == label_name }

    return existing_label.id if existing_label

    # Create new label
    new_label = Google::Apis::GmailV1::Label.new(
      name: label_name,
      label_list_visibility: "labelShow",
      message_list_visibility: "show"
    )

    created_label = @gmail_service.create_user_label("me", new_label)
    created_label.id
  end

  # Extract attachments from message parts recursively
  def extract_attachments_from_parts(part, message_id, save_path, attachments)
    if part.parts&.any?
      part.parts.each do |subpart|
        extract_attachments_from_parts(subpart, message_id, save_path, attachments)
      end
    elsif part.filename.present? && part.body&.attachment_id.present?
      attachment_info = {
        filename: part.filename,
        mime_type: part.mime_type,
        size: part.body.size,
        attachment_id: part.body.attachment_id
      }

      if save_path
        file_path = download_attachment(message_id, part.body.attachment_id, part.filename, save_path)
        attachment_info[:file_path] = file_path
      end

      attachments << attachment_info
    end
  end

  # Download an attachment
  def download_attachment(message_id, attachment_id, filename, save_path)
    FileUtils.mkdir_p(save_path) unless Dir.exist?(save_path)

    attachment = @gmail_service.get_user_message_attachment("me", message_id, attachment_id)

    file_path = File.join(save_path, filename)
    File.open(file_path, "wb") do |file|
      file.write(Base64.urlsafe_decode64(attachment.data))
    end

    file_path
  end

  # Process a message based on configured actions
  def process_message(message, actions)
    actions.each do |action, params|
      case action.to_s
      when "add_label"
        add_label(message.id, params[:label_name]) if params[:label_name]
      when "mark_as_read"
        mark_as_read(message.id) if params[:mark_read]
      when "extract_attachments"
        get_attachments(message.id, save_path: params[:save_path]) if params[:save_path]
      when "forward"
        forward_message(message, params[:to]) if params[:to]
      end
    end
  end

  # Forward a message
  def forward_message(message, to)
    subject = "Fwd: #{extract_subject(message)}"
    body = "---------- Forwarded message ----------\n#{extract_body(message)}"

    send_message(to: to, subject: subject, body: body)
  end

  # Extract subject from message
  def extract_subject(message)
    header = message.payload.headers.find { |h| h.name == "Subject" }
    header&.value || "No Subject"
  end

  # Extract body from message
  def extract_body(message)
    if message.payload.parts&.any?
      text_part = message.payload.parts.find { |part| part.mime_type == "text/plain" }
      return Base64.urlsafe_decode64(text_part.body.data) if text_part&.body&.data
    end

    if message.payload.body&.data
      Base64.urlsafe_decode64(message.payload.body.data)
    else
      "No body content"
    end
  end

  # Render email template with data
  def render_email_template(template, data)
    # Simple template rendering - in production, use a proper template engine
    rendered = template.dup
    data.each do |key, value|
      rendered.gsub!("{{#{key}}}", value.to_s)
    end
    rendered
  end
end
