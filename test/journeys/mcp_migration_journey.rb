# test/journeys/mcp_migration_journey.rb
# Browser test journey for MCP server to configuration migration

module Journeys
  class McpMigrationJourney < BaseJourney
    def call
      login_as_admin
      
      # Visit admin MCP servers page
      visit "/admin/mcp_servers"
      assert_text "MCP Servers (Legacy)"
      assert_text "deprecation notice", wait: 3
      
      # Should see existing servers
      assert_text "Legacy Linear Server"
      assert_text "Legacy GitHub Server"
      
      # Convert first server
      within("tr", text: "Legacy Linear Server") do
        click_button "Convert to Configuration"
      end
      
      # Confirm conversion
      assert_text "Convert MCP Server to Configuration?"
      click_button "Convert"
      
      assert_text "Successfully converted to configuration"
      
      # Visit configurations to see converted config
      visit "/mcp_configurations"
      assert_text "Legacy Linear Server"
      assert_selector ".badge", text: "Active"
      
      # Check metadata shows it was migrated
      within("[data-config-name='Legacy Linear Server']") do
        click_link "Edit"
      end
      
      assert_text "Created from legacy MCP server"
      
      # Go back and convert all servers
      visit "/admin/mcp_servers"
      
      click_button "Convert All Servers"
      accept_confirm
      
      assert_text "Converting all MCP servers..."
      assert_text "Conversion complete", wait: 10
      
      # Verify all servers are converted
      visit "/mcp_configurations"
      assert_text "Legacy Linear Server"
      assert_text "Legacy GitHub Server"
      
      # Test that old endpoints still work (compatibility layer)
      visit "/api/v1/mcp_servers"
      
      # Should return both old and new in compatibility mode
      assert_json_includes "servers", min_count: 2
      
      success_message "MCP migration journey completed successfully"
    end
    
    private
    
    def login_as_admin
      visit "/users/sign_in"
      fill_in "Email", with: "admin@example.com"
      fill_in "Password", with: "admin123"
      click_button "Sign in"
      
      assert_text "Signed in successfully"
    end
    
    def assert_json_includes(key, min_count: 1)
      # Check that JSON response includes expected data
      json = JSON.parse(page.body)
      assert json[key].is_a?(Array), "Expected #{key} to be an array"
      assert json[key].length >= min_count, "Expected at least #{min_count} #{key}"
    end
  end
end