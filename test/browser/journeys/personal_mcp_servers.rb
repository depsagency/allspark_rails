# frozen_string_literal: true

require_relative '../base_journey'

class PersonalMcpServersJourney < BaseJourney
  include JourneyHelper

  def run_personal_mcp_servers_journey
    with_error_handling do
      
      step "Login as regular user" do
        login_as("testuser@example.com", "password123")
        expect_no_errors
      end

      step "Navigate to user profile" do
        visit "/users"
        
        # Find the current user and navigate to their profile
        if @session.has_content?("testuser@example.com")
          expect_success("Found user profile page")
        else
          # Try finding user by ID
          user = User.find_by(email: "testuser@example.com")
          if user
            visit "/users/#{user.id}"
            expect_success("Navigated to user profile by ID")
          else
            expect_error("Test user not found")
          end
        end
        
        screenshot("user_profile_page")
        expect_no_errors
      end

      step "Access personal MCP servers section" do
        # Look for MCP Servers link in profile
        if @session.has_link?("MCP Servers")
          click_link "MCP Servers"
          expect_success("Clicked MCP Servers link")
        else
          # Try direct navigation
          user = User.find_by(email: "testuser@example.com")
          visit "/users/#{user.id}/mcp_servers"
          expect_success("Navigated directly to MCP servers page")
        end
        
        expect_page_to_have("Personal MCP Servers")
        screenshot("personal_mcp_servers_page")
        expect_no_errors
      end

      step "Verify page shows expected sections" do
        expect_page_to_have("Personal Servers")
        expect_page_to_have("System Servers")
        expect_page_to_have("Add Personal Server")
        
        # Check stats cards
        expect_page_to_have("Personal Servers")
        expect_page_to_have("Active")
        expect_page_to_have("System Servers")
        expect_page_to_have("Health")
        
        screenshot("mcp_servers_overview")
        expect_no_errors
      end

      step "Create a personal MCP server" do
        # Click the first Add Personal Server button (in header)
        @session.first("button", text: "Add Personal Server").click
        
        # Wait for modal to open
        sleep(1)
        
        # Fill in server details using the label text
        fill_in "Server Name", with: "My Personal Test Server"
        fill_in "Endpoint URL", with: "https://personal-test.example.com/mcp/v1"
        select "API Key", from: "Authentication Type"
        
        # Wait for JavaScript to show API key fields
        sleep(2)
        
        # Fill in API key using JavaScript if needed
        if @session.has_field?("mcp_server[credentials][api_key]")
          fill_in "mcp_server[credentials][api_key]", with: "personal-test-api-key-123"
        else
          @session.execute_script("document.querySelector('[data-personal-mcp-server-form-target=\"apiKeyFields\"]').style.display = 'block';")
          sleep(1)
          fill_in "mcp_server[credentials][api_key]", with: "personal-test-api-key-123"
        end
        
        screenshot("personal_server_form_filled")
        # Click the submit button within the modal
        @session.find("input[type=submit][value='Add Personal Server']").click
        
        # Wait for form submission
        sleep(3)
        
        # Debug what happened after form submission
        puts "After form submission:"
        puts "Current URL: #{@session.current_url}"
        puts "Current path: #{@session.current_path}"
        puts "Page has 'successfully created': #{@session.has_content?('successfully created')}"
        puts "Page has error messages: #{@session.has_content?('error')}"
        
        # Check if server was created in database
        user = User.find_by(email: "testuser@example.com")
        created_server = user.mcp_servers.find_by(name: "My Personal Test Server")
        puts "Server in database: #{created_server.present?}"
        
        # Navigate back to ensure we're on the right page
        visit "/users/#{user.id}/mcp_servers"
        expect_success("Navigated back to MCP servers page")
        
        expect_no_errors
      end

      step "Verify personal server appears in list" do
        # Debug current state
        puts "Current URL: #{@session.current_url}"
        puts "Current path: #{@session.current_path}"
        
        # Navigate back to MCP servers page if needed
        if !@session.current_path.include?("/mcp_servers")
          user = User.find_by(email: "testuser@example.com")
          visit "/users/#{user.id}/mcp_servers"
        end
        
        expect_page_to_have("My Personal Test Server")
        expect_page_to_have("https://personal-test.example.com/mcp/v1")
        expect_page_to_have("Private")
        
        # Check that server appears in personal servers section
        personal_servers_section = @session.find("h2", text: /Personal Servers/).ancestor("div", class: "card")
        expect(personal_servers_section).to have_content("My Personal Test Server")
        
        screenshot("personal_server_created")
        expect_no_errors
      end

      step "Test personal server management" do
        # Find the server's dropdown menu
        server_card = @session.find("div", text: "My Personal Test Server").ancestor("div", class: "border")
        
        within(server_card) do
          # Click the dropdown button
          @session.find("button", class: "btn-ghost").click
          sleep(1)
          
          # Test connection
          click_link "Test Connection"
        end
        
        # Wait for test to complete (will likely fail but should handle gracefully)
        sleep(3)
        
        # Should still be on the MCP servers page
        expect_page_to_have("Personal MCP Servers")
        screenshot("connection_test_completed")
        expect_no_errors
      end

      step "Edit personal server" do
        # Find server card and edit
        server_card = @session.find("div", text: "My Personal Test Server").ancestor("div", class: "border")
        
        within(server_card) do
          @session.find("button", class: "btn-ghost").click
          sleep(1)
          click_link "Edit"
        end
        
        # Wait for edit modal to open
        sleep(2)
        
        # Update server name
        fill_in "Server Name", with: "Updated Personal Test Server"
        click_button "Update Server"
        
        # Wait for update
        sleep(3)
        
        # Verify update
        expect_page_to_have("Updated Personal Test Server")
        screenshot("personal_server_updated")
        expect_no_errors
      end

      step "Verify system servers are visible" do
        # Check that system servers section exists and shows available servers
        system_servers_section = @session.find("h2", text: /System Servers/).ancestor("div", class: "card")
        
        within(system_servers_section) do
          # Should see either system servers or a message about none configured
          has_servers = @session.has_content?("System-wide") || 
                       @session.has_content?("No system-wide MCP servers")
          
          expect(has_servers).to be_truthy
        end
        
        screenshot("system_servers_section")
        expect_no_errors
      end

      step "Test access control - verify server is user-specific" do
        # Personal server should be marked as "Private"
        expect_page_to_have("Private")
        
        # Get current user to verify server ownership
        user = User.find_by(email: "testuser@example.com")
        personal_server = user.mcp_servers.find_by(name: "Updated Personal Test Server")
        
        expect(personal_server).to be_present
        expect(personal_server.user_id).to eq(user.id)
        expect(personal_server.instance_id).to be_nil
        
        expect_success("Personal server correctly associated with user")
        expect_no_errors
      end

      step "Clean up - delete personal server" do
        # Find server card and delete
        server_card = @session.find("div", text: "Updated Personal Test Server").ancestor("div", class: "border")
        
        within(server_card) do
          @session.find("button", class: "btn-ghost").click
          sleep(1)
          
          @session.accept_confirm do
            click_link "Delete"
          end
        end
        
        # Wait for deletion
        sleep(3)
        
        # Verify server is removed
        expect(@session).not_to have_content("Updated Personal Test Server")
        screenshot("personal_server_deleted")
        expect_no_errors
      end

      step "Verify final state" do
        # Should be back to empty personal servers state
        expect_page_to_have("Personal MCP Servers")
        expect_page_to_have("No personal servers configured")
        
        screenshot("cleanup_completed")
        expect_no_errors
      end

    end
  end
end