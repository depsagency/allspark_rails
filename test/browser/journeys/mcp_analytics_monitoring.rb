# frozen_string_literal: true

require_relative '../base_journey'

class McpAnalyticsMonitoringJourney < BaseJourney
  include JourneyHelper

  def run_mcp_analytics_monitoring_journey
    with_error_handling do
      
      step "Login as admin user" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end
      
      step "Access analytics dashboard" do
        visit "/admin/mcp_servers/analytics"
        expect_page_to_have("MCP Analytics Dashboard")
        expect_page_to_have("Monitor MCP server performance")
        
        screenshot("analytics_dashboard_loaded")
        expect_no_errors
      end

      step "Verify overview metrics" do
        expect_page_to_have("Total Servers")
        expect_page_to_have("Total Executions")
        expect_page_to_have("Avg Response Time")
        expect_page_to_have("Tools Available")
        
        screenshot("overview_metrics")
        expect_no_errors
      end

      step "Check usage trends chart" do
        expect_page_to_have("Usage Trends")
        
        # Look for Chart.js canvas elements
        expect(@session).to have_css("canvas")
        
        screenshot("usage_trends_chart")
        expect_no_errors
      end

      step "Verify response time distribution" do
        expect_page_to_have("Response Time Distribution")
        
        # Should have multiple charts
        canvas_count = @session.all("canvas").size
        expect(canvas_count).to be >= 1
        
        screenshot("response_time_distribution")
        expect_no_errors
      end

      step "Review top performing servers" do
        expect_page_to_have("Top Performing Servers")
        
        # Table should exist even if empty
        has_table = @session.has_css?("table") || @session.has_content?("No activity")
        expect(has_table).to be true
        
        screenshot("top_performing_servers")
        expect_no_errors
      end

      step "Check most used tools" do
        expect_page_to_have("Most Used Tools")
        
        # Should show tools or empty state
        has_tools = @session.has_content?("executions") || @session.has_content?("No tools")
        
        screenshot("most_used_tools")
        expect_no_errors
      end

      step "Verify server health status" do
        expect_page_to_have("Server Health Status")
        expect_page_to_have("Healthy Servers")
        expect_page_to_have("Warning Servers")
        expect_page_to_have("Critical Servers")
        
        screenshot("server_health_status")
        expect_no_errors
      end

      step "Check recent activity" do
        expect_page_to_have("Recent Activity")
        
        # Should have activity table or empty state
        has_activity = @session.has_css?("table") || @session.has_content?("No recent activity")
        expect(has_activity).to be true
        
        screenshot("recent_activity")
        expect_no_errors
      end

      step "Test timeframe selection" do
        if @session.has_button?("Time Range: Last 7 Days") || @session.has_button?("Time Range")
          @session.find('button', text: /Time Range/).click
          
          if @session.has_link?("Last 24 Hours")
            click_link "Last 24 Hours"
            
            expect_page_to_have("Last 24 Hours") || expect_page_to_have("MCP Analytics Dashboard")
            
            screenshot("timeframe_changed")
            expect_no_errors
          end
        end
      end

      step "Test data export functionality" do
        if @session.has_button?("Export Data")
          click_button "Export Data"
          
          # Export will likely fail in test but should handle gracefully
          sleep(2)
          expect_no_js_errors
          
          screenshot("export_attempted")
        end
      end

      step "Verify mobile responsiveness" do
        # Test responsive design
        @session.driver.resize_window(375, 667) if @session.driver.respond_to?(:resize_window)
        
        expect_page_to_have("MCP Analytics Dashboard")
        expect(@session).to have_css(".grid")
        
        screenshot("mobile_responsive")
        
        # Reset to desktop size
        @session.driver.resize_window(1024, 768) if @session.driver.respond_to?(:resize_window)
        
        expect_no_errors
      end

      step "Navigate back to admin servers index" do
        visit "/admin/mcp_servers"
        expect_page_to_have("MCP Servers")
        
        # Verify analytics link is available
        expect(@session).to have_link("Analytics")
        
        screenshot("back_to_admin_index")
        expect_no_errors
      end

    end
  end
end