require 'rails_helper'

RSpec.describe "MCP Configurations", type: :system do
  let(:user) { create(:user) }
  
  before do
    login_as(user, scope: :user)
  end
  
  describe "listing configurations" do
    let!(:config1) { create(:mcp_configuration, owner: user, name: "Linear Integration") }
    let!(:config2) { create(:mcp_configuration, owner: user, name: "GitHub Integration", enabled: false) }
    
    it "displays user configurations" do
      visit mcp_configurations_path
      
      expect(page).to have_content("MCP Configurations")
      expect(page).to have_content("Linear Integration")
      expect(page).to have_content("GitHub Integration")
      
      # Check status badges
      within("[data-config-id='#{config1.id}']") do
        expect(page).to have_content("Active")
      end
      
      within("[data-config-id='#{config2.id}']") do
        expect(page).to have_content("Disabled")
      end
    end
    
    it "shows template gallery" do
      visit mcp_configurations_path
      
      expect(page).to have_content("Available Templates")
      expect(page).to have_content("Linear")
      expect(page).to have_content("GitHub")
      expect(page).to have_content("Slack")
    end
  end
  
  describe "creating configuration from template" do
    it "creates Linear configuration" do
      visit mcp_configurations_path
      
      # Click on Linear template
      within(".template-card", text: "Linear") do
        click_link "Use Template"
      end
      
      # Fill in the form
      fill_in "Configuration Name", with: "My Linear Integration"
      fill_in "LINEAR_API_KEY", with: "test-linear-key-123"
      
      click_button "Create Configuration"
      
      expect(page).to have_content("Configuration created successfully")
      expect(page).to have_content("My Linear Integration")
      
      # Verify it was created correctly
      config = McpConfiguration.last
      expect(config.name).to eq("My Linear Integration")
      expect(config.server_type).to eq("stdio")
      expect(config.metadata["template_key"]).to eq("linear")
    end
  end
  
  describe "creating custom configuration" do
    it "creates HTTP configuration" do
      visit new_mcp_configuration_path
      
      fill_in "Configuration Name", with: "Custom API"
      select "http", from: "Server Type"
      
      # Fill in server config
      fill_in "Endpoint", with: "https://api.example.com/mcp"
      fill_in "Headers", with: '{"Authorization": "Bearer token123"}'
      
      click_button "Create Configuration"
      
      expect(page).to have_content("Configuration created successfully")
      expect(page).to have_content("Custom API")
    end
  end
  
  describe "editing configuration" do
    let!(:configuration) { create(:mcp_configuration, owner: user, name: "Edit Me") }
    
    it "updates configuration" do
      visit mcp_configurations_path
      
      within("[data-config-id='#{configuration.id}']") do
        click_link "Edit"
      end
      
      fill_in "Configuration Name", with: "Updated Name"
      click_button "Update Configuration"
      
      expect(page).to have_content("Configuration updated successfully")
      expect(page).to have_content("Updated Name")
    end
  end
  
  describe "toggling configuration" do
    let!(:configuration) { create(:mcp_configuration, owner: user, enabled: true) }
    
    it "disables and enables configuration" do
      visit mcp_configurations_path
      
      within("[data-config-id='#{configuration.id}']") do
        expect(page).to have_content("Active")
        
        accept_confirm do
          click_button "Disable"
        end
      end
      
      expect(page).to have_content("Disabled")
      
      within("[data-config-id='#{configuration.id}']") do
        click_button "Enable"
      end
      
      expect(page).to have_content("Active")
    end
  end
  
  describe "testing configuration" do
    let!(:configuration) { create(:mcp_configuration, owner: user) }
    
    it "shows test results", js: true do
      visit mcp_configurations_path
      
      within("[data-config-id='#{configuration.id}']") do
        click_link "Test Connection"
      end
      
      # Wait for AJAX
      expect(page).to have_content(/Test (successful|failed)/)
    end
  end
  
  describe "deleting configuration" do
    let!(:configuration) { create(:mcp_configuration, owner: user) }
    
    it "removes configuration" do
      visit mcp_configurations_path
      
      within("[data-config-id='#{configuration.id}']") do
        accept_confirm do
          click_button "Delete"
        end
      end
      
      expect(page).to have_content("Configuration deleted successfully")
      expect(page).not_to have_content(configuration.name)
    end
  end
end