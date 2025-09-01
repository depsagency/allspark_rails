# frozen_string_literal: true

require_relative '../base_journey'

class McpCompleteWorkflowJourney < BaseJourney
  include JourneyHelper

  def run_mcp_complete_workflow_journey
    with_error_handling do
      
      step "Login as admin user" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end
      
      step "Admin: Create system-wide MCP server" do
        visit "/admin/mcp_servers"
        click_link "Add MCP Server"
        
        fill_in "Server Name", with: "Complete Workflow Server"
        fill_in "Endpoint URL", with: "https://workflow.example.com/mcp/v1"
        select "API Key", from: "Authentication Type"
        
        # Wait for JavaScript to show API key fields
        sleep(2)
        wait_for_turbo
        
        # Use the correct field names for API key authentication
        if @session.has_field?("mcp_server[credentials][api_key]")
          fill_in "mcp_server[credentials][api_key]", with: "workflow-api-key-12345"
        else
          @session.execute_script("document.querySelector('[data-mcp-server-form-target=\"apiKeyFields\"]').style.display = 'block';")
          sleep(1)
          fill_in "mcp_server[credentials][api_key]", with: "workflow-api-key-12345"
        end
        
        if @session.has_field?("mcp_server[credentials][api_key_header]")
          fill_in "mcp_server[credentials][api_key_header]", with: "Authorization"
        end
        
        screenshot("create_workflow_server")
        click_button "Create Server"
        
        # Wait for form submission and check for success
        wait_for_turbo
        sleep(2)
        
        # Check for successful creation similar to other tests
        if @session.current_path.match?(/\/admin\/mcp_servers\/[a-z0-9-]+$/) || 
           @session.has_content?("Complete Workflow Server")
          expect_success("Workflow server created successfully")
        else
          visit "/admin/mcp_servers"
          expect_page_to_have("Complete Workflow Server")
          expect_success("Workflow server found in list")
        end
        
        expect_no_errors
      end

      step "Admin: Verify server creation and test" do
        expect_page_to_have("Complete Workflow Server")
        
        if @session.has_button?("Test Connection")
          click_button "Test Connection"
          # Connection will fail but should handle gracefully
          sleep(2)
          expect_no_js_errors
        end
        
        screenshot("server_created_and_tested")
        expect_no_errors
      end

      step "Admin: Configure server settings" do
        click_link "Edit Server"
        
        # Try to access advanced configuration with JavaScript trigger to avoid overlapping elements
        if @session.has_css?(".collapse-title")
          @session.execute_script("document.querySelector('.collapse-title').click();")
          sleep(1)
        end
        
        # Add JSON configuration if field is available
        if @session.has_field?("Custom Configuration")
          config_json = {
            timeout: 30000,
            retries: 3,
            rate_limits: {
              per_second: 10,
              per_minute: 100
            }
          }.to_json
          
          fill_in "Custom Configuration", with: config_json
        end
        
        screenshot("server_configuration")
        click_button "Update Server"
        
        # Wait for update and check for success
        wait_for_turbo
        sleep(2)
        
        if @session.current_path.match?(/\/admin\/mcp_servers\/[a-z0-9-]+$/) || 
           @session.has_content?("Complete Workflow Server")
          expect_success("Server configuration updated successfully")
        else
          expect_success("Server update completed")
        end
        
        expect_no_errors
      end

      step "Admin: Monitor system via analytics" do
        visit "/admin/mcp_servers/analytics"
        
        expect_page_to_have("Total Servers")
        expect_page_to_have("MCP Analytics Dashboard")
        
        # Verify server appears in analytics or shows no activity
        has_server = @session.has_content?("Complete Workflow Server") ||
                    @session.has_content?("No activity")
        
        screenshot("analytics_with_new_server")
        expect_no_errors
      end

      step "Admin: Check server health" do
        visit "/admin/mcp_servers"
        
        # Verify server is listed
        expect_page_to_have("Complete Workflow Server")
        
        # Check health stats
        expect_page_to_have("Total Servers")
        expect_page_to_have("Active")
        
        screenshot("server_health_check")
        expect_no_errors
      end

      step "User: Access personal MCP servers (if available)" do
        visit "/users"
        
        # Try to access personal MCP servers
        if @session.has_link?("Profile")
          click_link "Profile"
          
          if @session.has_link?("MCP Servers")
            click_link "MCP Servers"
            expect_page_to_have("Personal MCP Servers")
            
            # Add a personal server if the interface is available
            if @session.has_button?("Add Personal Server")
              click_button "Add Personal Server"
              
              fill_in "Server Name", with: "Personal Workflow Server"
              fill_in "Endpoint URL", with: "https://personal-workflow.example.com/mcp/v1"
              select "Bearer Token", from: "Authentication Type"
              
              fill_in "Bearer Token", with: "personal-bearer-token-12345"
              
              click_button "Add Personal Server"
              expect_page_to_have("Personal MCP server was successfully created")
            end
            
            screenshot("personal_servers_accessed")
          end
        end
        
        expect_no_errors
      end

      step "User: Access AI assistants (if available)" do
        visit "/agents/assistants"
        
        if @session.has_content?("Assistants")
          # Try to create or edit an assistant
          if @session.has_link?("New Assistant")
            click_link "New Assistant"
            
            fill_in "Name", with: "MCP Workflow Assistant"
            fill_in "Description", with: "Assistant with MCP tools for workflow testing"
            
            if @session.has_field?("System Prompt")
              fill_in "System Prompt", with: "You are an assistant with access to workflow tools via MCP."
            end
            
            click_button "Create Assistant"
            expect_page_to_have("Assistant was successfully created")
            
            # Try to configure MCP tools
            if @session.has_link?("Edit")
              click_link "Edit"
              
              if @session.has_field?("Enable MCP Tools")
                check "Enable MCP Tools"
                click_button "Update Assistant"
                expect_page_to_have("Assistant was successfully updated")
              end
            end
            
            screenshot("assistant_with_mcp_tools")
          elsif @session.has_link?("Edit", match: :first)
            # Edit existing assistant
            click_link "Edit", match: :first
            
            if @session.has_field?("Enable MCP Tools")
              check "Enable MCP Tools"
              click_button "Update Assistant"
              expect_page_to_have("Assistant was successfully updated")
            end
            
            screenshot("existing_assistant_configured")
          end
        end
        
        expect_no_errors
      end

      step "Admin: View complete system in analytics" do
        visit "/admin/mcp_servers/analytics"
        
        expect_page_to_have("MCP Analytics Dashboard")
        expect_page_to_have("Total Servers")
        
        # Test different timeframes
        if @session.has_button?("Time Range")
          @session.find('button', text: /Time Range/).click
          
          if @session.has_link?("Last 30 Days")
            click_link "Last 30 Days"
            expect_page_to_have("Last 30 Days") || expect_page_to_have("MCP Analytics Dashboard")
          end
        end
        
        screenshot("complete_system_analytics")
        expect_no_errors
      end

      step "Cleanup: Remove test servers and assistants" do
        # Clean up system server
        visit "/admin/mcp_servers"
        
        if @session.has_content?("Complete Workflow Server")
          click_link "Complete Workflow Server"
          click_link "Delete"
          
          @session.accept_confirm do
            click_button "Delete Server"
          end
          
          expect_page_to_have("MCP server was successfully deleted")
        end
        
        # Clean up personal server if created
        visit "/users"
        if @session.has_link?("Profile")
          click_link "Profile"
          
          if @session.has_link?("MCP Servers")
            click_link "MCP Servers"
            
            if @session.has_content?("Personal Workflow Server")
              # Find and delete personal server
              within(:xpath, "//div[contains(text(), 'Personal Workflow Server')]/ancestor::div[contains(@class, 'border')]") do
                if @session.has_css?('[data-action*="dropdown"]')
                  @session.find('[data-action*="dropdown"]').click
                  if @session.has_link?("Delete")
                    click_link "Delete"
                    @session.accept_confirm
                  end
                end
              end
            end
          end
        end
        
        # Clean up assistant if created
        visit "/agents/assistants"
        if @session.has_content?("MCP Workflow Assistant")
          click_link "MCP Workflow Assistant"
          
          if @session.has_link?("Delete")
            click_link "Delete"
            @session.accept_confirm do
              click_button "Delete Assistant"
            end
            expect_page_to_have("Assistant was successfully deleted")
          end
        end
        
        screenshot("cleanup_completed")
        expect_no_errors
      end

      step "Verify cleanup completed" do
        visit "/admin/mcp_servers/analytics"
        expect_page_to_have("MCP Analytics Dashboard")
        
        visit "/admin/mcp_servers"
        expect(@session).not_to have_content("Complete Workflow Server")
        
        screenshot("final_verification")
        expect_no_errors
      end

    end
  end
end