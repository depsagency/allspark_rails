# test/journeys/mcp_configuration_journey.rb
# Browser test journey for MCP configuration management

module Journeys
  class McpConfigurationJourney < BaseJourney
    def call
      login_as_user
      
      # Visit MCP configurations page
      visit "/mcp_configurations"
      assert_text "MCP Configurations"
      assert_text "Available Templates"
      
      # Create configuration from Linear template
      within(".template-gallery") do
        find(".template-card", text: "Linear").click_link("Use Template")
      end
      
      # Fill in template form
      fill_in "Configuration Name", with: "My Linear Integration"
      fill_in "LINEAR_API_KEY", with: "test-linear-api-key-123"
      
      click_button "Create Configuration"
      
      # Verify creation
      assert_text "Configuration created successfully"
      assert_text "My Linear Integration"
      assert_selector ".badge", text: "Active"
      
      # Test the configuration
      within("[data-config-name='My Linear Integration']") do
        click_button "Test Connection"
      end
      
      # Wait for test result
      assert_text(/Connection (successful|test passed)/, wait: 5)
      
      # Edit the configuration
      within("[data-config-name='My Linear Integration']") do
        click_link "Edit"
      end
      
      fill_in "Configuration Name", with: "Updated Linear Integration"
      click_button "Update Configuration"
      
      assert_text "Configuration updated successfully"
      assert_text "Updated Linear Integration"
      
      # Disable the configuration
      within("[data-config-name='Updated Linear Integration']") do
        click_button "Disable"
      end
      
      assert_selector ".badge", text: "Disabled"
      
      # Create a custom HTTP configuration
      click_link "New Configuration"
      
      fill_in "Configuration Name", with: "Custom API Integration"
      select "http", from: "Server Type"
      
      # Fill in HTTP details
      within("#server-config-fields") do
        fill_in "Endpoint", with: "https://api.example.com/mcp"
        fill_in "Headers", with: '{"Authorization": "Bearer test-token"}'
      end
      
      click_button "Create Configuration"
      
      assert_text "Configuration created successfully"
      assert_text "Custom API Integration"
      
      # Clean up - delete configurations
      ["Updated Linear Integration", "Custom API Integration"].each do |config_name|
        within("[data-config-name='#{config_name}']") do
          accept_confirm do
            click_button "Delete"
          end
        end
        
        assert_no_text config_name
      end
      
      success_message "MCP configuration journey completed successfully"
    end
    
    private
    
    def login_as_user
      visit "/users/sign_in"
      fill_in "Email", with: "test@example.com"
      fill_in "Password", with: "password123"
      click_button "Sign in"
      
      assert_text "Signed in successfully"
    end
  end
end