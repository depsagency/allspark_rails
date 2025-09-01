require_relative '../base_journey'

class ChatTestJourney < BaseJourney
  include JourneyHelper

  journey :chat_test do
    setup_session

    begin
      step "Login as first user" do
        login_as("admin@example.com", "password123")
      end

      step "Visit chat page" do
        visit "/chat"
        expect_no_errors
        sleep 2 # Wait for page to load
      end

      step "Check if chat interface loaded" do
        # Check for key elements
        expect_page_to_have("chat-container")
        expect_page_to_have("General Discussion") # Thread name
      end

      step "Send a test message" do
        fill_in "Type a message...", with: "Test message from browser #{Time.current}"
        # Find and click the send button
        find('button[type="submit"]').click
        sleep 2 # Wait for message to send
      end

      step "Check if message appears" do
        expect_page_to_have("Test message from browser")
      end

    ensure
      teardown_session
    end
  end
end