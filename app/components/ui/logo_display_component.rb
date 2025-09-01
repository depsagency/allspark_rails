# frozen_string_literal: true

# Logo Display component for showing generated logos
#
# Displays a generated logo with metadata, download options, and generation status
#
# Example usage:
#   <%= render Ui::LogoDisplayComponent.new(app_project: @app_project) %>
#
class Ui::LogoDisplayComponent < BaseComponent
  option :app_project
  option :show_metadata, default: -> { true }
  option :show_actions, default: -> { true }
  option :css_class, optional: true

  private

  def container_classes
    classes = [ "logo-display", "bg-base-100", "rounded-lg", "p-4" ]
    classes << css_class if css_class.present?
    classes.join(" ")
  end

  def has_logo?
    # Match the marketing page helper logic exactly
    attached = app_project.generated_logo.attached?
    url_present = app_project.generated_logo_url.present?
    data_present = app_project.logo_data.present?
    metadata_present = app_project.logo_generation_metadata&.dig("original_url").present?
    logo_generated = app_project.ai_generations.where(generation_type: "logo", status: "completed").exists?

    Rails.logger.debug "LogoDisplayComponent.has_logo? - attached: #{attached}, url_present: #{url_present}, data_present: #{data_present}, metadata_present: #{metadata_present}, logo_generated: #{logo_generated}"

    attached || url_present || data_present || metadata_present || logo_generated
  end

  def logo_url
    # Match the same logic as the marketing page helper
    if app_project.logo_data.present?
      data_url = "data:image/png;base64,#{app_project.logo_data}"
      Rails.logger.debug "LogoDisplayComponent.logo_url - Using stored base64 data (#{app_project.logo_data.length} chars)"
      data_url
    elsif app_project.generated_logo_url.present? && valid_url?(app_project.generated_logo_url)
      Rails.logger.debug "LogoDisplayComponent.logo_url - Using stored URL: #{app_project.generated_logo_url[0..50]}..."
      app_project.generated_logo_url
    elsif app_project.logo_generation_metadata&.dig("original_url").present?
      # Logo data stored in metadata - same as marketing page helper
      logo_data = app_project.logo_generation_metadata["original_url"]
      data_url = "data:image/png;base64,#{logo_data}"
      Rails.logger.debug "LogoDisplayComponent.logo_url - Using metadata base64 data (#{logo_data.length} chars)"
      data_url
    elsif app_project.generated_logo.attached?
      begin
        # Fallback to Active Storage if no data available
        url = Rails.application.routes.url_helpers.rails_blob_path(app_project.generated_logo, only_path: true)
        Rails.logger.debug "LogoDisplayComponent.logo_url - Active Storage fallback: #{url}"
        url
      rescue => e
        Rails.logger.error "Failed to generate Active Storage path: #{e.message}"
        nil
      end
    else
      Rails.logger.debug "LogoDisplayComponent.logo_url - No logo URL available"
      nil
    end
  end

  def valid_url?(url)
    url.start_with?("http://", "https://", "data:image")
  end

  def logo_filename
    if app_project.generated_logo.attached?
      app_project.generated_logo.filename.to_s
    else
      "#{app_project.slug}-logo.png"
    end
  end

  def generation_cost
    app_project.logo_generation_cost
  end

  def formatted_cost
    cost = generation_cost
    return "$0.00" if cost.nil? || cost.zero?
    "$#{cost.round(4)}"
  end

  def generation_model
    app_project.logo_generation_metadata&.dig("model") || "Unknown"
  end

  def generation_date
    generated_at = app_project.logo_generation_metadata&.dig("generated_at")
    return "Unknown" unless generated_at

    Time.parse(generated_at).strftime("%B %d, %Y at %I:%M %p")
  end

  def processing_time
    time = app_project.logo_generation_metadata&.dig("processing_time")
    return "N/A" unless time

    if time < 60
      "#{time.round(1)}s"
    else
      minutes = (time / 60).floor
      seconds = (time % 60).round
      "#{minutes}m #{seconds}s"
    end
  end

  def image_size
    app_project.logo_generation_metadata&.dig("size") || "1024x1024"
  end

  def can_regenerate?
    app_project.logo_ready_for_generation? && !app_project.generating?
  end

  def download_url
    logo_url
  end
end
