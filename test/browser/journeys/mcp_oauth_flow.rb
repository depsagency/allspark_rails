# frozen_string_literal: true

require_relative '../base_journey'

class McpOauthFlowJourney < BaseJourney
  include JourneyHelper

  def run_mcp_oauth_flow_journey
    with_error_handling do
      
      step "Login as admin user" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end
      
      step "Create OAuth-enabled MCP server" do
        visit "/admin/mcp_servers/new"
        expect_page_to_have("Add MCP Server")
        
        fill_in "Server Name", with: "OAuth Test Server"
        fill_in "Endpoint URL", with: "https://oauth.example.com/mcp/v1"
        select "OAuth 2.0", from: "Authentication Type"
        
        # Wait for OAuth fields to appear
        @session.find_field("Client ID")
        
        fill_in "Client ID", with: "test-client-id"
        fill_in "Client Secret", with: "test-client-secret"
        fill_in "Authorization URL", with: "https://oauth.example.com/oauth/authorize"
        fill_in "Token URL", with: "https://oauth.example.com/oauth/token"
        fill_in "OAuth Scope", with: "read write"
        fill_in "Revocation URL", with: "https://oauth.example.com/oauth/revoke"
        
        screenshot("oauth_server_form")
        click_button "Create Server"
        expect_page_to_have("MCP server was successfully created")
        expect_no_errors
      end

      step "View OAuth server status" do
        click_link "OAuth Test Server"
        expect_page_to_have("OAuth Test Server")
        expect_page_to_have("OAuth 2.0")
        
        # Should show OAuth authorization required
        has_oauth_status = @session.has_content?("OAuth Authorization Required") || 
                          @session.has_link?("Start OAuth")
        
        screenshot("oauth_server_status")
        expect_no_errors
      end

      step "Edit OAuth configuration" do
        click_link "Edit"
        expect_page_to_have("Edit OAuth Test Server")
        
        # Verify OAuth fields are populated
        expect(@session.find_field("Client ID").value).to eq("test-client-id")
        expect(@session.find_field("Authorization URL").value).to eq("https://oauth.example.com/oauth/authorize")
        
        # Update configuration
        fill_in "OAuth Scope", with: "read write admin"
        
        screenshot("edit_oauth_server")
        click_button "Update Server"
        expect_page_to_have("MCP server was successfully updated")
        expect_no_errors
      end

      step "View OAuth server in analytics" do
        visit "/admin/mcp_servers/analytics"
        expect_page_to_have("MCP Analytics Dashboard")
        
        # Should show OAuth server or no activity message
        has_server = @session.has_content?("OAuth Test Server") || 
                    @session.has_content?("No activity")
        
        screenshot("analytics_with_oauth_server")
        expect_no_errors
      end

      step "Clean up OAuth test server" do
        visit "/admin/mcp_servers"
        click_link "OAuth Test Server"
        click_link "Delete"
        
        @session.accept_confirm do
          click_button "Delete Server"
        end
        
        expect_page_to_have("MCP server was successfully deleted")
        expect_no_errors
        screenshot("oauth_cleanup_complete")
      end

    end
  end
end