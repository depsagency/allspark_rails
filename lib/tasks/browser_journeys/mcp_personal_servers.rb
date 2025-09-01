# frozen_string_literal: true

# MCP Personal Servers Journey
# Tests user-specific MCP server management

journey :mcp_personal_servers do
  description "User manages their personal MCP servers"
  
  step "Navigate to user profile" do
    # Go to current user's profile
    visit "/users"
    
    if page.has_link?("View Profile", match: :first)
      click_link "View Profile", match: :first
    else
      # Navigate to own profile
      click_link "Profile" # or however profile is accessed in nav
    end
    
    expect(page).to have_content("Profile") || have_content("User")
  end
  
  step "Access personal MCP servers" do
    click_link "MCP Servers"
    expect(page).to have_content("Personal MCP Servers")
    expect(page).to have_content("About Personal MCP Servers")
  end
  
  step "Add first personal MCP server" do
    click_button "Add Personal Server"
    expect(page).to have_content("Add Personal MCP Server")
    
    fill_in "Server Name", with: "My Personal Server"
    fill_in "Endpoint URL", with: "https://personal.example.com/mcp/v1"
    select "API Key", from: "Authentication Type"
    
    # Wait for API key fields
    expect(page).to have_field("API Key")
    fill_in "API Key", with: "personal-api-key-12345"
    
    click_button "Add Personal Server"
    expect(page).to have_content("Personal MCP server was successfully created")
  end
  
  step "View personal server details" do
    expect(page).to have_content("My Personal Server")
    expect(page).to have_badge("Private")
    expect(page).to have_content("API Key")
  end
  
  step "Test personal server connection" do
    # Open server actions dropdown
    click_button "⋮" # or the dropdown trigger
    click_link "Test Connection"
    
    expect(page).to have_content("Connection test")
  end
  
  step "Edit personal server" do
    click_button "⋮"
    click_link "Edit"
    
    fill_in "Server Name", with: "Updated Personal Server"
    fill_in "Endpoint URL", with: "https://updated.example.com/mcp/v1"
    
    click_button "Update Server"
    expect(page).to have_content("Personal MCP server was successfully updated")
  end
  
  step "Add second personal server with OAuth" do
    click_button "Add Personal Server"
    
    fill_in "Server Name", with: "OAuth Personal Server"
    fill_in "Endpoint URL", with: "https://oauth-personal.example.com/mcp/v1"
    select "OAuth 2.0", from: "Authentication Type"
    
    # Fill OAuth configuration
    fill_in "Client ID", with: "personal-oauth-client"
    fill_in "Authorization URL", with: "https://oauth-personal.example.com/auth"
    fill_in "Token URL", with: "https://oauth-personal.example.com/token"
    fill_in "Scope", with: "personal:read personal:write"
    
    click_button "Add Personal Server"
    expect(page).to have_content("Personal MCP server was successfully created")
  end
  
  step "Verify privacy notices and health stats" do
    expect(page).to have_content("Privacy Notice")
    expect(page).to have_content("Personal Servers: 2")
    expect(page).to have_content("Overall health status")
  end
  
  step "View system servers as regular user" do
    expect(page).to have_content("System Servers") || 
           have_content("No system-wide MCP servers")
    
    # System servers should be read-only for regular users
    expect(page).not_to have_button("Edit") # For system servers
  end
  
  step "Clean up personal servers" do
    # Delete first server
    within(:xpath, "//div[contains(text(), 'Updated Personal Server')]/ancestor::div[contains(@class, 'border')]") do
      click_button "⋮"
      click_link "Delete"
    end
    
    page.accept_confirm do
      click_button "Delete"
    end
    
    expect(page).to have_content("Personal MCP server was successfully deleted")
    
    # Delete second server
    within(:xpath, "//div[contains(text(), 'OAuth Personal Server')]/ancestor::div[contains(@class, 'border')]") do
      click_button "⋮"
      click_link "Delete"
    end
    
    page.accept_confirm do
      click_button "Delete"
    end
    
    expect(page).to have_content("Personal MCP server was successfully deleted")
  end
  
  step "Verify empty state" do
    expect(page).to have_content("No personal servers configured")
    expect(page).to have_button("Add First Personal Server")
  end
end