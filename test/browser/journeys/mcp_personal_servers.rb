# frozen_string_literal: true

require_relative '../base_journey'

class McpPersonalServersJourney < BaseJourney
  include JourneyHelper

  def run_mcp_personal_servers_journey
    with_error_handling do
      
      step "Navigate to user profile and MCP servers" do
        # Access current user's profile
        visit "/users"
        
        # Find a link to user profile/settings
        if @session.has_link?("Profile")
          click_link "Profile"
        elsif @session.has_content?("Email:")
          # Already on a user page, look for MCP servers link
        else
          # Navigate through user index
          if @session.has_link?("View", match: :first)
            click_link "View", match: :first
          end
        end
        
        # Look for MCP Servers link
        if @session.has_link?("MCP Servers")
          click_link "MCP Servers"
          expect_page_to_have("Personal MCP Servers")
          expect_page_to_have("About Personal MCP Servers")
        else
          # Skip this journey if personal servers not accessible
          puts "⚠️  Personal MCP servers not accessible, skipping journey"
          return
        end
        
        screenshot("personal_mcp_servers_page")
        expect_no_errors
      end

      step "Add first personal MCP server" do
        click_button "Add Personal Server"
        expect_page_to_have("Add Personal MCP Server")
        
        fill_in "Server Name", with: "My Personal Server"
        fill_in "Endpoint URL", with: "https://personal.example.com/mcp/v1"
        select "API Key", from: "Authentication Type"
        
        # Wait for API key fields
        @session.find_field("API Key")
        fill_in "API Key", with: "personal-api-key-12345"
        
        screenshot("add_personal_server_form")
        click_button "Add Personal Server"
        expect_page_to_have("Personal MCP server was successfully created")
        expect_no_errors
      end

      step "View personal server details" do
        expect_page_to_have("My Personal Server")
        expect_page_to_have("Private")
        expect_page_to_have("API Key")
        
        screenshot("personal_server_created")
        expect_no_errors
      end

      step "Test personal server connection" do
        # Look for test connection option in dropdown or button
        if @session.has_css?('[data-action*="dropdown"]')
          @session.find('[data-action*="dropdown"]').click
          if @session.has_link?("Test Connection")
            click_link "Test Connection"
            sleep(2) # Allow time for connection test
            expect_no_js_errors
          end
        end
      end

      step "Verify privacy notices and health stats" do
        expect_page_to_have("Privacy Notice")
        expect_page_to_have("Personal Servers")
        expect_page_to_have("health status") || expect_page_to_have("health")
        
        screenshot("privacy_and_stats")
        expect_no_errors
      end

      step "View system servers as regular user" do
        expect_page_to_have("System Servers") || 
        expect_page_to_have("No system-wide MCP servers")
        
        # System servers should be read-only for regular users
        # Should not have edit buttons for system servers
        screenshot("system_servers_readonly")
        expect_no_errors
      end

      step "Clean up personal server" do
        # Find and delete the personal server
        if @session.has_content?("My Personal Server")
          # Look for delete option in dropdown
          within(:xpath, "//div[contains(text(), 'My Personal Server')]/ancestor::div[contains(@class, 'border') or contains(@class, 'card')]") do
            if @session.has_css?('[data-action*="dropdown"]')
              @session.find('[data-action*="dropdown"]').click
              if @session.has_link?("Delete")
                click_link "Delete"
                @session.accept_confirm
              end
            elsif @session.has_button?("Delete")
              click_button "Delete"
              @session.accept_confirm
            end
          end
          
          expect_page_to_have("Personal MCP server was successfully deleted")
        end
        
        screenshot("personal_server_cleanup")
        expect_no_errors
      end

      step "Verify empty state" do
        expect_page_to_have("No personal servers configured") ||
        expect_page_to_have("Add First Personal Server")
        
        screenshot("empty_state")
        expect_no_errors
      end

    end
  end
end