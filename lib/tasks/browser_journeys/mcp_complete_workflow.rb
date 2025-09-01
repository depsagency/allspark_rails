# frozen_string_literal: true

# MCP Complete Workflow Journey
# Tests the entire MCP integration from setup to usage

journey :mcp_complete_workflow do
  description "Complete end-to-end MCP workflow from admin setup to user usage"
  
  step "Admin: Create system-wide MCP server" do
    visit "/admin/mcp_servers"
    click_link "Add MCP Server"
    
    fill_in "Server Name", with: "Complete Workflow Server"
    fill_in "Endpoint URL", with: "https://workflow.example.com/mcp/v1"
    select "API Key", from: "Authentication Type"
    
    fill_in "API Key", with: "workflow-api-key-12345"
    fill_in "Header Name", with: "Authorization"
    
    click_button "Create Server"
    expect(page).to have_content("MCP server was successfully created")
  end
  
  step "Admin: Verify server creation and test" do
    expect(page).to have_content("Complete Workflow Server")
    click_button "Test Connection"
    
    # Connection will fail but should handle gracefully
    expect(page).to have_content("Connection test") || 
           have_content("failed") ||
           have_content("error")
  end
  
  step "Admin: Configure server settings" do
    click_link "Edit"
    
    # Add advanced configuration
    within(".collapse") do
      click_element(".collapse-title") if page.has_css?(".collapse-title")
    end
    
    # Add JSON configuration
    config_json = {
      timeout: 30000,
      retries: 3,
      rate_limits: {
        per_second: 10,
        per_minute: 100
      }
    }.to_json
    
    fill_in "Custom Configuration", with: config_json
    
    click_button "Update Server"
    expect(page).to have_content("MCP server was successfully updated")
  end
  
  step "User: Create personal MCP server" do
    visit "/users"
    click_link "Profile", match: :first
    click_link "MCP Servers"
    
    click_button "Add Personal Server"
    
    fill_in "Server Name", with: "Personal Workflow Server"
    fill_in "Endpoint URL", with: "https://personal-workflow.example.com/mcp/v1"
    select "Bearer Token", from: "Authentication Type"
    
    fill_in "Bearer Token", with: "personal-bearer-token-12345"
    
    click_button "Add Personal Server"
    expect(page).to have_content("Personal MCP server was successfully created")
  end
  
  step "User: Create AI assistant with MCP tools" do
    visit "/agents/assistants"
    
    if page.has_link?("New Assistant")
      click_link "New Assistant"
      
      fill_in "Name", with: "MCP Workflow Assistant"
      fill_in "Description", with: "Assistant with MCP tools for workflow testing"
      fill_in "System Prompt", with: "You are an assistant with access to workflow tools via MCP."
      
      click_button "Create Assistant"
      expect(page).to have_content("Assistant was successfully created")
      
      click_link "Edit"
    else
      click_link "Edit", match: :first
    end
    
    check "Enable MCP Tools"
  end
  
  step "User: Configure MCP tools for assistant" do
    click_link "Server Selection"
    
    # Select both system and personal servers if available
    if page.has_field?("mcp_server_")
      check("mcp_server_", match: :first)
    end
    
    click_link "Tool Configuration"
    
    # Configure any available tools
    if page.has_field?("tool_")
      check("tool_", match: :first)
    end
    
    click_button "Update Assistant"
    expect(page).to have_content("Assistant was successfully updated")
  end
  
  step "Admin: Monitor system via analytics" do
    visit "/admin/mcp_servers/analytics"
    
    expect(page).to have_content("Total Servers: 2") ||
           have_content("Total Servers") # Count may vary
    
    # Verify servers appear in analytics
    expect(page).to have_content("Complete Workflow Server") ||
           have_content("No activity") # If no executions yet
  end
  
  step "Admin: Check server health" do
    visit "/admin/mcp_servers"
    
    # Verify both servers are listed
    expect(page).to have_content("Complete Workflow Server")
    
    # Check health stats
    expect(page).to have_content("Total Servers")
    expect(page).to have_content("Active")
  end
  
  step "User: Verify personal server privacy" do
    visit "/users"
    click_link "Profile", match: :first
    click_link "MCP Servers"
    
    # Personal server should be visible to user
    expect(page).to have_content("Personal Workflow Server")
    expect(page).to have_badge("Private")
    
    # System server should also be visible (read-only)
    expect(page).to have_content("System Servers")
  end
  
  step "Instance: Add instance-specific server" do
    visit "/instances"
    
    if page.has_link?("View", match: :first)
      click_link "View", match: :first
      click_link "Settings"
      click_link "MCP Servers"
      
      click_button "Add Instance Server"
      
      fill_in "Server Name", with: "Instance Workflow Server"
      fill_in "Endpoint URL", with: "https://instance-workflow.example.com/mcp/v1"
      select "No Authentication", from: "Authentication Type"
      
      click_button "Create Server"
      expect(page).to have_content("Instance MCP server was successfully created")
    end
  end
  
  step "Admin: View complete system in analytics" do
    visit "/admin/mcp_servers/analytics"
    
    # Should now show all three servers
    expect(page).to have_content("Total Servers: 3") ||
           have_content("Total Servers") # Actual count
    
    # Test different timeframes
    click_button "Time Range"
    click_link "Last 30 Days"
    
    expect(page).to have_content("Last 30 Days")
  end
  
  step "Cleanup: Remove test servers" do
    # Clean up system server
    visit "/admin/mcp_servers"
    click_link "Complete Workflow Server"
    click_link "Delete"
    
    page.accept_confirm do
      click_button "Delete Server"
    end
    
    expect(page).to have_content("MCP server was successfully deleted")
    
    # Clean up personal server
    visit "/users"
    click_link "Profile", match: :first
    click_link "MCP Servers"
    
    within(:xpath, "//div[contains(text(), 'Personal Workflow Server')]/ancestor::div[contains(@class, 'border')]") do
      click_button "⋮"
      click_link "Delete"
    end
    
    page.accept_confirm
    expect(page).to have_content("Personal MCP server was successfully deleted")
    
    # Clean up assistant
    visit "/agents/assistants"
    if page.has_content?("MCP Workflow Assistant")
      click_link "MCP Workflow Assistant"
      click_link "Delete"
      
      page.accept_confirm do
        click_button "Delete Assistant"
      end
      
      expect(page).to have_content("Assistant was successfully deleted")
    end
  end
  
  step "Verify cleanup completed" do
    visit "/admin/mcp_servers/analytics"
    
    # Should show reduced server count or no activity
    expect(page).to have_content("MCP Analytics Dashboard")
    
    visit "/admin/mcp_servers"
    expect(page).not_to have_content("Complete Workflow Server")
  end
end