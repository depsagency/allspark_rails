# frozen_string_literal: true

class User < ApplicationRecord
  # Include concerns
  include HasMcpConfigurations
  include McpFeatureFlags
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  # Associations
  has_many :notifications, dependent: :destroy
  has_many :sent_notifications, class_name: "Notification", foreign_key: "sender_id", dependent: :nullify
  has_many :app_projects, dependent: :destroy
  has_one_attached :avatar
  
  # Chat associations
  has_many :created_chat_threads, class_name: "ChatThread", foreign_key: "created_by_id", dependent: :destroy
  has_many :chat_thread_participants, dependent: :destroy
  has_many :chat_threads, through: :chat_thread_participants
  has_many :chat_messages, dependent: :destroy
  
  # AI Agent associations
  has_many :assistants, dependent: :destroy
  has_many :external_integrations, dependent: :destroy
  has_many :agent_teams, dependent: :destroy
  has_many :knowledge_documents, dependent: :destroy
  
  # Impersonation associations
  has_many :impersonated_audit_logs, class_name: 'ImpersonationAuditLog', foreign_key: 'impersonated_user_id', dependent: :destroy
  has_many :impersonator_audit_logs, class_name: 'ImpersonationAuditLog', foreign_key: 'impersonator_id', dependent: :destroy
  
  # MCP associations
  has_many :mcp_servers, dependent: :destroy
  
  # Chat scopes
  has_many :participating_threads, through: :chat_thread_participants, source: :chat_thread

  # Roles for authorization
  enum :role, {
    default: 0,
    system_admin: 1
  }, default: :default

  # Social platforms configuration
  SOCIAL_PLATFORMS = {
    twitter: { base_url: "https://twitter.com/", type: :username, placeholder: "username" },
    github: { base_url: "https://github.com/", type: :username, placeholder: "username" },
    linkedin: { base_url: "https://linkedin.com/in/", type: :username, placeholder: "username" },
    instagram: { base_url: "https://instagram.com/", type: :username, placeholder: "username" },
    tiktok: { base_url: "https://tiktok.com/@", type: :username, placeholder: "username" },
    youtube: { base_url: "https://youtube.com/", type: :url, placeholder: "channel URL" },
    facebook: { base_url: "https://facebook.com/", type: :username, placeholder: "username" },
    threads: { base_url: "https://threads.net/@", type: :username, placeholder: "username" }
  }.freeze

  # Validations
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }
  validates :bio, length: { maximum: 500 }
  validate :validate_social_links

  # Callbacks
  after_initialize :set_default_role, if: :new_record?

  def full_name
    return nil unless first_name.present? || last_name.present?
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.presence || email
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name.first}#{last_name.first}".upcase
    elsif first_name.present?
      first_name.first(2).upcase
    elsif email.present?
      email.first(2).upcase
    else
      "U"
    end
  end

  # Role helper methods
  def admin?
    system_admin?
  end

  def can_access_admin?
    system_admin?
  end

  def role_name
    role.humanize
  end

  # Notification convenience methods
  def notify!(title:, message:, type: "info", **options)
    notifications.create!(
      title: title,
      message: message,
      notification_type: type,
      **options
    )
  end

  def send_notification(title:, message:, sender: nil, **options)
    notification = notify!(
      title: title,
      message: message,
      sender: sender,
      **options
    )
    notification.deliver_now
    notification
  end

  def unread_notifications_count
    notifications.unread.count
  end

  def mark_all_notifications_read!
    notifications.unread.update_all(
      read_at: Time.current,
      updated_at: Time.current
    )
  end

  # Dynamic social link methods
  SOCIAL_PLATFORMS.each do |platform, config|
    # Getter method (e.g., twitter_handle)
    define_method("#{platform}_handle") do
      social_links&.dig(platform.to_s)
    end

    # Setter method (e.g., twitter_handle=)
    define_method("#{platform}_handle=") do |value|
      self.social_links ||= {}
      if value.present?
        # Clean up the value
        cleaned_value = value.strip
        cleaned_value = cleaned_value.gsub(/^@/, "") if config[:type] == :username
        self.social_links[platform.to_s] = cleaned_value
      else
        self.social_links.delete(platform.to_s)
      end
    end

    # URL method (e.g., twitter_url)
    define_method("#{platform}_url") do
      handle = send("#{platform}_handle")
      return nil unless handle.present?

      if config[:type] == :username
        "#{config[:base_url]}#{handle}"
      else
        # For :url type, ensure it has protocol
        handle.start_with?("http") ? handle : "https://#{handle}"
      end
    end
  end

  # Backward compatibility aliases
  alias_method :github_username, :github_handle
  alias_method :linkedin_url, :linkedin_handle

  def has_social_links?
    social_links.present? && social_links.any? { |_, v| v.present? }
  end

  def title
    # You can customize this based on your needs
    # For now, returning nil as we don't have a title field
    nil
  end

  # Impersonation methods
  def can_impersonate?(user)
    return false unless system_admin?
    return false if user == self
    return false if user.system_admin? # Admins cannot impersonate other admins
    true
  end

  def being_impersonated?
    # Check if there's an active impersonation session for this user
    impersonated_audit_logs.active.exists?
  end

  def current_impersonator
    return nil unless being_impersonated?
    impersonated_audit_logs.active.first&.impersonator
  end

  def active_impersonation_log
    impersonated_audit_logs.active.first
  end

  def impersonation_history
    impersonated_audit_logs.recent.limit(50)
  end

  private

  def set_default_role
    self.role ||= :default
  end

  def validate_social_links
    return unless social_links.present?

    social_links.each do |platform, value|
      next unless value.present?

      platform_sym = platform.to_sym
      next unless SOCIAL_PLATFORMS.key?(platform_sym)

      config = SOCIAL_PLATFORMS[platform_sym]

      if config[:type] == :username
        # Validate username format
        unless value.match?(/\A[a-zA-Z0-9_.-]+\z/)
          errors.add(:base, "#{platform.capitalize} username can only contain letters, numbers, underscores, periods, and hyphens")
        end
      elsif config[:type] == :url
        # Validate URL format for platforms that need full URLs
        unless value.match?(/\Ahttps?:\/\//) || value.match?(/\A[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/)
          errors.add(:base, "#{platform.capitalize} must be a valid URL")
        end
      end
    end
  end
end
