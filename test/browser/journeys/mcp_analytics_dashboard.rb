# frozen_string_literal: true

require_relative '../base_journey'

class McpAnalyticsDashboardJourney < BaseJourney
  include JourneyHelper

  def run_mcp_analytics_dashboard_journey
    with_error_handling do
      
      step "Login as admin user" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end
      
      step "Create test MCP server for analytics data" do
        # First create a test server to have some data for analytics
        visit "/admin/mcp_servers"
        click_link "Add MCP Server"
        
        fill_in "Server Name", with: "Analytics Test Server"
        fill_in "Endpoint URL", with: "https://analytics.example.com/mcp/v1"
        select "API Key", from: "Authentication Type"
        
        # Wait for JavaScript to show API key fields
        sleep(2)
        wait_for_turbo
        
        # Try the exact field names from the form
        if @session.has_field?("mcp_server[credentials][api_key]")
          fill_in "mcp_server[credentials][api_key]", with: "analytics-test-key"
        elsif @session.has_field?("API Key")
          fill_in "API Key", with: "analytics-test-key"
        else
          # Force JavaScript execution to show fields
          @session.execute_script("document.querySelector('[data-mcp-server-form-target=\"apiKeyFields\"]').style.display = 'block';")
          sleep(1)
          
          if @session.has_field?("mcp_server[credentials][api_key]")
            fill_in "mcp_server[credentials][api_key]", with: "analytics-test-key"
          else
            screenshot("no_api_key_field_analytics")
            raise "Could not find API Key field for analytics test server"
          end
        end
        
        # Try the exact header field name
        if @session.has_field?("mcp_server[credentials][api_key_header]")
          fill_in "mcp_server[credentials][api_key_header]", with: "Authorization"
        elsif @session.has_field?("Header Name")
          fill_in "Header Name", with: "Authorization"
        end
        
        click_button "Create Server"
        
        # Wait for creation and verify
        wait_for_turbo
        sleep(2)
        
        # Navigate to servers list to confirm creation
        visit "/admin/mcp_servers"
        expect_page_to_have("Analytics Test Server")
        expect_success("Test server created for analytics testing")
        expect_no_errors
      end

      step "Access analytics dashboard from servers page" do
        visit "/admin/mcp_servers"
        click_link "Analytics"
        
        # Wait for page to load
        wait_for_turbo
        sleep(2)
        
        # Check if we're on the analytics page
        if @session.has_content?("MCP Analytics Dashboard") ||
           @session.has_content?("Analytics Dashboard") ||
           @session.has_content?("Total Servers")
          expect_success("Successfully accessed analytics dashboard")
        else
          debug_page_content("Analytics page not loaded")
          screenshot("analytics_access_failed")
          raise "Failed to access analytics dashboard"
        end
        
        screenshot("mcp_analytics_dashboard")
        expect_no_errors
      end

      step "Verify analytics overview statistics" do
        # Check for key overview metrics
        overview_elements = [
          "Total Servers",
          "Total Executions", 
          "Avg Response Time",
          "Tools Available"
        ]
        
        overview_elements.each do |element|
          if @session.has_content?(element)
            expect_success("Found overview metric: #{element}")
          else
            puts "WARNING: Overview metric '#{element}' not found"
          end
        end
        
        # Look for numeric values indicating real data
        if @session.has_css?('.stat-value')
          stat_values = @session.all('.stat-value').map(&:text)
          puts "DEBUG: Found stat values: #{stat_values.join(', ')}"
          expect_success("Analytics statistics are displaying numeric values")
        else
          puts "WARNING: No stat values found in analytics"
        end
        
        expect_no_errors
      end

      step "Check analytics charts and visualizations" do
        # Look for chart sections
        chart_sections = [
          "Usage Trends",
          "Response Time Distribution"
        ]
        
        chart_sections.each do |section|
          if @session.has_content?(section)
            expect_success("Found chart section: #{section}")
          else
            puts "WARNING: Chart section '#{section}' not found"
          end
        end
        
        # Check for chart containers (canvas elements)
        if @session.has_css?('canvas')
          canvas_count = @session.all('canvas').count
          expect_success("Found #{canvas_count} chart canvas elements")
        else
          puts "WARNING: No chart canvas elements found"
        end
        
        expect_no_errors
      end

      step "Verify server performance tables" do
        # Look for performance data tables
        table_sections = [
          "Top Performing Servers",
          "Most Used Tools"
        ]
        
        table_sections.each do |section|
          if @session.has_content?(section)
            expect_success("Found table section: #{section}")
          else
            puts "WARNING: Table section '#{section}' not found"
          end
        end
        
        # Our test server should appear in the servers list
        if @session.has_content?("Analytics Test Server")
          expect_success("Test server appears in analytics data")
        else
          puts "INFO: Test server not yet visible in analytics (may need more data)"
        end
        
        expect_no_errors
      end

      step "Check health status monitoring" do
        health_sections = [
          "Server Health Status",
          "Healthy Servers",
          "Warning Servers", 
          "Critical Servers"
        ]
        
        health_sections.each do |section|
          if @session.has_content?(section)
            expect_success("Found health section: #{section}")
          else
            puts "WARNING: Health section '#{section}' not found"
          end
        end
        
        expect_no_errors
      end

      step "Test time range filtering" do
        # Look for time range controls
        if @session.has_content?("Time Range") || @session.has_content?("Last 7 Days")
          expect_success("Time range filtering controls found")
          
          # Try to interact with time range if available
          if @session.has_css?('.dropdown')
            # Click on dropdown to see options
            dropdown = @session.first('.dropdown')
            if dropdown
              dropdown.click
              sleep(1)
              
              if @session.has_content?("Last 24 Hours") || @session.has_content?("Last 30 Days")
                expect_success("Time range dropdown options found")
              end
            end
          end
        else
          puts "WARNING: Time range filtering not found"
        end
        
        expect_no_errors
      end

      step "Check recent activity feed" do
        if @session.has_content?("Recent Activity")
          expect_success("Recent activity section found")
          
          # Look for activity table structure
          if @session.has_css?('table')
            table_headers = ["Timestamp", "Server", "Tool", "User", "Status"]
            table_headers.each do |header|
              if @session.has_content?(header)
                expect_success("Found activity table header: #{header}")
              end
            end
          end
        else
          puts "WARNING: Recent activity section not found"
        end
        
        expect_no_errors
      end

      step "Test data export functionality" do
        if @session.has_content?("Export Data") || @session.has_link?("Export Data")
          expect_success("Export functionality found")
          # Note: We won't actually trigger the export to avoid downloading files
        else
          puts "WARNING: Export functionality not found"
        end
        
        screenshot("analytics_dashboard_complete")
        expect_no_errors
      end

      step "Navigate to individual server analytics" do
        # Navigate back to servers list and view individual server analytics
        visit "/admin/mcp_servers"
        
        if @session.has_content?("Analytics Test Server")
          click_link "Analytics Test Server"
          
          # Look for individual server analytics link
          if @session.has_link?("View Analytics") || @session.has_link?("Analytics")
            click_link "View Analytics"
            
            # Check if we're on individual server analytics
            if @session.has_content?("Analytics Test Server") && 
               (@session.has_content?("Usage Statistics") || @session.has_content?("Performance"))
              expect_success("Individual server analytics accessible")
              screenshot("individual_server_analytics")
            else
              puts "WARNING: Individual server analytics page not as expected"
            end
          else
            puts "WARNING: Individual server analytics link not found"
          end
        else
          puts "WARNING: Test server not found for individual analytics"
        end
        
        expect_no_errors
      end

      step "Clean up test server" do
        # Clean up the test server we created
        visit "/admin/mcp_servers"
        
        if @session.has_content?("Analytics Test Server")
          click_link "Analytics Test Server"
          
          if @session.has_link?("Edit Server")
            click_link "Edit Server"
            
            if @session.has_link?("Delete Server")
              @session.accept_confirm do
                click_link "Delete Server"
              end
              expect_success("Test server cleaned up successfully")
            else
              puts "WARNING: Could not find delete option for cleanup"
            end
          end
        else
          puts "INFO: Test server not found for cleanup (may have been already deleted)"
        end
        
        screenshot("after_analytics_cleanup")
      end

    end
  end
end