# frozen_string_literal: true

# MCP Admin Management Journey
# Tests the complete admin workflow for managing MCP servers

journey :mcp_admin_management do
  description "Admin creates, configures, and manages MCP servers"
  
  step "Navigate to admin MCP servers page" do
    visit "/admin/mcp_servers"
    expect(page).to have_content("MCP Servers")
    expect(page).to have_link("Add MCP Server")
  end
  
  step "Create new MCP server with API key authentication" do
    click_link "Add MCP Server"
    expect(page).to have_content("Add MCP Server")
    
    fill_in "Server Name", with: "Test API Server"
    fill_in "Endpoint URL", with: "https://api.example.com/mcp/v1"
    select "API Key", from: "Authentication Type"
    
    # Wait for auth fields to appear
    expect(page).to have_field("API Key")
    fill_in "API Key", with: "test-api-key-12345"
    fill_in "Header Name", with: "X-API-Key"
    
    click_button "Create Server"
    expect(page).to have_content("MCP server was successfully created")
  end
  
  step "View server details and monitoring" do
    click_link "Test API Server"
    expect(page).to have_content("Test API Server")
    expect(page).to have_content("https://api.example.com/mcp/v1")
    expect(page).to have_content("API Key")
    
    # Check monitoring tab
    click_link "Monitoring"
    expect(page).to have_content("Usage Statistics")
  end
  
  step "Test server connection" do
    click_button "Test Connection"
    # Note: This will fail in test but should show proper error handling
    expect(page).to have_content("Connection test")
  end
  
  step "Edit server configuration" do
    click_link "Edit"
    expect(page).to have_content("Edit Test API Server")
    
    fill_in "Server Name", with: "Updated API Server"
    select "Inactive", from: "Status"
    
    click_button "Update Server"
    expect(page).to have_content("MCP server was successfully updated")
    expect(page).to have_content("Updated API Server")
  end
  
  step "Access analytics dashboard" do
    visit "/admin/mcp_servers"
    click_link "Analytics"
    expect(page).to have_content("MCP Analytics Dashboard")
    expect(page).to have_content("Total Servers")
    expect(page).to have_content("Usage Trends")
  end
  
  step "Perform bulk operations" do
    visit "/admin/mcp_servers"
    
    # Select server for bulk action
    check "server_ids_"
    select "Activate", from: "bulk_action"
    click_button "Execute"
    
    expect(page).to have_content("Bulk action completed")
  end
  
  step "Clean up test data" do
    # Delete the test server
    visit "/admin/mcp_servers"
    click_link "Updated API Server"
    click_link "Delete"
    
    # Confirm deletion
    page.accept_confirm do
      click_button "Delete Server"
    end
    
    expect(page).to have_content("MCP server was successfully deleted")
  end
end