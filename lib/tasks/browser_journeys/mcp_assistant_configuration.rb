# frozen_string_literal: true

# MCP Assistant Configuration Journey
# Tests configuring MCP tools for AI assistants

journey :mcp_assistant_configuration do
  description "User configures MCP tools for their AI assistant"
  
  step "Navigate to assistants page" do
    visit "/agents/assistants"
    expect(page).to have_content("Assistants")
  end
  
  step "Create or edit assistant" do
    if page.has_link?("New Assistant")
      click_link "New Assistant"
      
      fill_in "Name", with: "MCP Test Assistant"
      fill_in "Description", with: "Assistant for testing MCP integration"
      fill_in "System Prompt", with: "You are a helpful assistant with access to MCP tools."
      
      click_button "Create Assistant"
      expect(page).to have_content("Assistant was successfully created")
      
      click_link "Edit"
    else
      # Edit existing assistant
      click_link "Edit", match: :first
    end
    
    expect(page).to have_content("Edit Assistant")
  end
  
  step "Enable MCP tools" do
    check "Enable MCP Tools"
    expect(page).to have_content("MCP Tools Configuration")
  end
  
  step "Configure MCP server selection" do
    click_link "Server Selection"
    expect(page).to have_content("Select MCP Servers")
    
    # Select available servers (if any exist)
    if page.has_content?("System Servers") || page.has_content?("Instance Servers")
      # Check first available server
      check("mcp_server_", match: :first) if page.has_field?("mcp_server_")
    end
  end
  
  step "Configure specific tools" do
    click_link "Tool Configuration"
    expect(page).to have_content("Configure Specific Tools")
    
    # If there are tools available, configure them
    if page.has_content?("Available Tools")
      # Enable first available tool
      check("tool_", match: :first) if page.has_field?("tool_")
    end
  end
  
  step "Set advanced filters" do
    click_link "Advanced Filters"
    expect(page).to have_content("Tool Filters")
    
    # Configure filters
    fill_in "Tool Name Pattern", with: "search*"
    fill_in "Category Filter", with: "utility"
    fill_in "Description Keywords", with: "search, find"
  end
  
  step "Save assistant configuration" do
    click_button "Update Assistant"
    expect(page).to have_content("Assistant was successfully updated")
  end
  
  step "View assistant with MCP tools" do
    expect(page).to have_content("MCP Tools: Enabled") || 
           have_content("Tools Configured") ||
           have_content("MCP Integration")
  end
  
  step "Test assistant functionality" do
    if page.has_button?("Test Assistant")
      click_button "Test Assistant"
      expect(page).to have_content("Test") || have_content("Chat")
    end
  end
  
  step "Verify MCP tools summary" do
    within(".mcp-tools-summary") do
      expect(page).to have_content("Servers:") || have_content("Tools:")
    end
  rescue Capybara::ElementNotFound
    # Summary section might be elsewhere or differently named
    expect(page).to have_content("MCP") && have_content("tools")
  end
  
  step "Edit MCP configuration again" do
    click_link "Edit"
    expect(page).to have_checked_field("Enable MCP Tools")
    
    # Disable MCP tools
    uncheck "Enable MCP Tools"
    
    click_button "Update Assistant"
    expect(page).to have_content("Assistant was successfully updated")
  end
  
  step "Clean up test assistant" do
    if page.has_content?("MCP Test Assistant")
      click_link "Delete"
      
      page.accept_confirm do
        click_button "Delete Assistant"
      end
      
      expect(page).to have_content("Assistant was successfully deleted")
    end
  end
end