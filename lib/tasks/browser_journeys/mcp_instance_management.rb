# frozen_string_literal: true

# MCP Instance Management Journey
# Tests instance-specific MCP server configuration

journey :mcp_instance_management do
  description "Instance admin configures MCP servers for their instance"
  
  step "Navigate to instance" do
    # Assume we have at least one instance
    visit "/instances"
    expect(page).to have_content("Instances")
    
    # Click on first instance or create one if none exist
    if page.has_link?("View", match: :first)
      click_link "View", match: :first
    else
      # Create test instance if none exist
      click_link "New Instance"
      fill_in "Name", with: "Test Instance"
      fill_in "Description", with: "Test instance for MCP"
      click_button "Create Instance"
    end
    
    expect(page).to have_content("Instance")
  end
  
  step "Access instance settings" do
    click_link "Settings"
    expect(page).to have_content("Instance Settings")
  end
  
  step "Navigate to MCP servers section" do
    click_link "MCP Servers"
    expect(page).to have_content("MCP Servers")
    expect(page).to have_content("Instance MCP Servers")
  end
  
  step "Add instance-specific MCP server" do
    click_button "Add Instance Server"
    
    fill_in "Server Name", with: "Instance Test Server"
    fill_in "Endpoint URL", with: "https://instance.example.com/mcp/v1"
    select "Bearer Token", from: "Authentication Type"
    
    # Wait for bearer token field
    expect(page).to have_field("Bearer Token")
    fill_in "Bearer Token", with: "bearer-token-12345"
    
    click_button "Create Server"
    expect(page).to have_content("Instance MCP server was successfully created")
  end
  
  step "View instance server details" do
    expect(page).to have_content("Instance Test Server")
    expect(page).to have_content("Bearer Token")
    expect(page).to have_badge("Instance")
  end
  
  step "Test instance server connection" do
    click_button "Test Connection"
    # Will show connection test result (likely failure in test)
    expect(page).to have_content("Connection test")
  end
  
  step "Edit instance server" do
    click_button "Edit"
    
    fill_in "Server Name", with: "Updated Instance Server"
    select "Inactive", from: "Status"
    
    click_button "Update Server"
    expect(page).to have_content("Instance MCP server was successfully updated")
  end
  
  step "Verify system servers are visible" do
    expect(page).to have_content("System Servers") || 
           have_content("No system-wide MCP servers")
  end
  
  step "Clean up instance server" do
    click_button "Delete"
    
    page.accept_confirm do
      click_button "Delete"
    end
    
    expect(page).to have_content("Instance MCP server was successfully deleted")
  end
end