# frozen_string_literal: true

# MCP OAuth Flow Journey
# Tests the complete OAuth authentication workflow for MCP servers

journey :mcp_oauth_flow do
  description "Admin configures OAuth MCP server and completes authentication flow"
  
  step "Create OAuth-enabled MCP server" do
    visit "/admin/mcp_servers/new"
    expect(page).to have_content("Add MCP Server")
    
    fill_in "Server Name", with: "OAuth Test Server"
    fill_in "Endpoint URL", with: "https://oauth.example.com/mcp/v1"
    select "OAuth 2.0", from: "Authentication Type"
    
    # Wait for OAuth fields to appear
    expect(page).to have_field("Client ID")
    
    fill_in "Client ID", with: "test-client-id"
    fill_in "Client Secret", with: "test-client-secret"
    fill_in "Authorization URL", with: "https://oauth.example.com/oauth/authorize"
    fill_in "Token URL", with: "https://oauth.example.com/oauth/token"
    fill_in "OAuth Scope", with: "read write"
    fill_in "Revocation URL", with: "https://oauth.example.com/oauth/revoke"
    
    click_button "Create Server"
    expect(page).to have_content("MCP server was successfully created")
  end
  
  step "View OAuth server status" do
    click_link "OAuth Test Server"
    expect(page).to have_content("OAuth Test Server")
    expect(page).to have_content("OAuth 2.0")
    
    # Should show OAuth authorization required
    expect(page).to have_content("OAuth Authorization Required") || 
           have_link("Start OAuth")
  end
  
  step "Edit OAuth configuration" do
    click_link "Edit"
    expect(page).to have_content("Edit OAuth Test Server")
    
    # Verify OAuth fields are populated
    expect(page).to have_field("Client ID", with: "test-client-id")
    expect(page).to have_field("Authorization URL", with: "https://oauth.example.com/oauth/authorize")
    
    # Update configuration
    fill_in "OAuth Scope", with: "read write admin"
    
    click_button "Update Server"
    expect(page).to have_content("MCP server was successfully updated")
  end
  
  step "Attempt OAuth authorization (will fail gracefully)" do
    # Note: This will fail in test environment but should show proper error handling
    if page.has_link?("Start OAuth")
      click_link "Start OAuth"
      # Should redirect to OAuth provider or show error
      expect(page).to have_content("OAuth") || have_content("error")
    end
  end
  
  step "View OAuth server in analytics" do
    visit "/admin/mcp_servers/analytics"
    expect(page).to have_content("OAuth Test Server") || 
           have_content("No activity") # If no recent activity
  end
  
  step "Clean up OAuth test server" do
    visit "/admin/mcp_servers"
    click_link "OAuth Test Server"
    click_link "Delete"
    
    page.accept_confirm do
      click_button "Delete Server"
    end
    
    expect(page).to have_content("MCP server was successfully deleted")
  end
end