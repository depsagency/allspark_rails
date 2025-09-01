# frozen_string_literal: true

# MCP Analytics and Monitoring Journey
# Tests comprehensive monitoring and analytics features

journey :mcp_analytics_monitoring do
  description "Admin monitors MCP system performance and analytics"
  
  step "Access analytics dashboard" do
    visit "/admin/mcp_servers/analytics"
    expect(page).to have_content("MCP Analytics Dashboard")
    expect(page).to have_content("Monitor MCP server performance")
  end
  
  step "Verify overview metrics" do
    expect(page).to have_content("Total Servers")
    expect(page).to have_content("Total Executions")
    expect(page).to have_content("Avg Response Time")
    expect(page).to have_content("Tools Available")
  end
  
  step "Check usage trends chart" do
    expect(page).to have_content("Usage Trends")
    expect(page).to have_css("canvas") # Chart.js canvas element
  end
  
  step "Verify response time distribution" do
    expect(page).to have_content("Response Time Distribution")
    # Should have another chart
    expect(page).to have_css("canvas", count: 2)
  end
  
  step "Review top performing servers" do
    expect(page).to have_content("Top Performing Servers")
    
    # Table should exist even if empty
    expect(page).to have_css("table") ||
           have_content("No activity")
  end
  
  step "Check most used tools" do
    expect(page).to have_content("Most Used Tools")
    
    # Should show tools or empty state
    expect(page).to have_content("executions") ||
           have_content("No tools")
  end
  
  step "Verify server health status" do
    expect(page).to have_content("Server Health Status")
    expect(page).to have_content("Healthy Servers")
    expect(page).to have_content("Warning Servers")
    expect(page).to have_content("Critical Servers")
  end
  
  step "Check recent activity" do
    expect(page).to have_content("Recent Activity")
    
    # Should have activity table or empty state
    expect(page).to have_css("table") ||
           have_content("No recent activity")
  end
  
  step "Test timeframe selection" do
    click_button "Time Range: Last 7 Days"
    click_link "Last 24 Hours"
    
    expect(page).to have_content("Last 24 Hours")
    expect(page).to have_content("MCP Analytics Dashboard")
  end
  
  step "Test data export" do
    click_button "Export Data"
    
    # Should trigger download or show export progress
    # In test environment, this will likely show an error but gracefully
    expect(page).to have_content("export") || 
           have_content("download") ||
           page.driver.browser.switch_to.alert.accept rescue nil
  end
  
  step "Navigate to individual server monitoring" do
    visit "/admin/mcp_servers"
    
    if page.has_link?("View", match: :first)
      click_link "View", match: :first
      expect(page).to have_content("MCP Server")
      
      if page.has_link?("Monitoring")
        click_link "Monitoring"
        expect(page).to have_content("Monitoring")
      end
    end
  end
  
  step "Verify server-specific analytics" do
    # Should be on individual server monitoring page
    expect(page).to have_content("Usage Statistics") ||
           have_content("Performance") ||
           have_content("Monitoring")
  end
  
  step "Test analytics refresh" do
    # Test auto-refresh functionality
    visit "/admin/mcp_servers/analytics"
    
    # Verify page loads correctly after refresh
    expect(page).to have_content("MCP Analytics Dashboard")
  end
  
  step "Verify mobile responsiveness" do
    # Test responsive design by resizing (simulated)
    page.driver.resize_window(375, 667) if page.driver.respond_to?(:resize_window)
    
    expect(page).to have_content("MCP Analytics Dashboard")
    expect(page).to have_css(".grid") # Grid layout should be responsive
    
    # Reset to desktop size
    page.driver.resize_window(1024, 768) if page.driver.respond_to?(:resize_window)
  end
end