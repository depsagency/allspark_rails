# frozen_string_literal: true

# @label Alert
class AlertComponentPreview < Lookbook::Preview
  # @label Basic Alert
  # @param type select { choices: [info, success, warning, error] }
  # @param dismissible toggle
  # @param title text "Alert Title"
  # @param message text "This is an alert message"
  def default(type: :info, dismissible: true, title: "Alert", message: "This is an alert message")
    render Ui::AlertComponent.new(
      type: type,
      dismissible: dismissible,
      title: title
    ) do
      message
    end
  end

  # @label Success Alert
  def success
    render Ui::AlertComponent.new(
      type: :success,
      dismissible: true,
      title: "Success!"
    ) do
      "Your changes have been saved successfully."
    end
  end

  # @label Auto-dismiss Alert
  def auto_dismiss
    render Ui::AlertComponent.new(
      type: :success,
      auto_dismiss: 5000,  # Disappears after 5 seconds
      title: "Success!"
    ) do
      "This alert will automatically disappear after 5 seconds."
    end
  end

  # @label Warning Alert
  def warning
    render Ui::AlertComponent.new(
      type: :warning,
      dismissible: true,
      title: "Warning"
    ) do
      "Please review your input before proceeding."
    end
  end

  # @label Error Alert
  def error
    render Ui::AlertComponent.new(
      type: :error,
      dismissible: true,
      title: "Error"
    ) do
      "Something went wrong. Please try again."
    end
  end

  # @label All Types
  def all_types
    render Ui::AlertComponent.new(
      type: :info,
      dismissible: true,
      title: "All Types Demo"
    ) do
      "This demonstrates multiple alert types. Check other scenarios for individual types."
    end
  end

  # @label Non-dismissible
  def non_dismissible
    render Ui::AlertComponent.new(
      type: :warning,
      dismissible: false,
      title: "System Maintenance"
    ) do
      "The system will be under maintenance from 2:00 AM to 4:00 AM UTC."
    end
  end

  # @label Custom Icons
  def custom_icons
    render Ui::AlertComponent.new(
      type: :info,
      dismissible: true,
      title: "Custom Icons Demo"
    ) do
      "This demonstrates custom icons. Check individual scenarios for different icon types."
    end
  end

  # @label Without Titles
  def without_titles
    render Ui::AlertComponent.new(
      type: :info,
      dismissible: true
    ) do
      "This is a simple informational alert without a title."
    end
  end

  # @label With Custom CSS
  def custom_styling
    render Ui::AlertComponent.new(
      type: :info,
      dismissible: true,
      title: "Enhanced Alert"
    ) do
      "This alert demonstrates custom styling capabilities."
    end
  end
end
