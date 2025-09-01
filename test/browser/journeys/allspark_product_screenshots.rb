# frozen_string_literal: true

require_relative '../base_journey'
require_relative '../helpers/journey_helper'

class AllsparkProductScreenshotsJourney < BaseJourney
  include JourneyHelper
  
  journey :allspark_product_screenshots do
    # Set up the screenshot directory for the product deck
    @screenshot_dir = Rails.root.join('docs', 'strategy', 'allspark-product-deck', 'assets')
    FileUtils.mkdir_p(@screenshot_dir)
    
    step "Login as admin" do
      login_as("admin@example.com", "password123")
      puts "✅ Logged in successfully"
      sleep 2
    end
    
    step "Capture homepage/dashboard" do
      visit "/"
      sleep 3  # Wait for page to fully load
      screenshot_path = File.join(@screenshot_dir, "homepage.png")
      screenshot(screenshot_path)
      puts "📸 Captured homepage"
    end
    
    step "Capture instance dashboard" do
      visit "/instances"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "instance-dashboard.png")
      screenshot(screenshot_path)
      puts "📸 Captured instance dashboard"
    end
    
    step "Capture projects list" do
      visit "/app_projects"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "projects-list.png")
      screenshot(screenshot_path)
      puts "📸 Captured projects list"
    end
    
    step "Capture project builder" do
      visit "/app_projects/new"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "project-builder.png")
      screenshot(screenshot_path)
      puts "📸 Captured project builder"
    end
    
    step "Capture AI assistants" do
      visit "/agents/assistants"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "assistants-list.png")
      screenshot(screenshot_path)
      puts "📸 Captured AI assistants"
    end
    
    step "Capture assistant chat" do
      # Try to find an assistant and go to its chat
      visit "/agents/assistants"
      if @session.has_css?(".assistant-card", wait: 2)
        # Click on the Chat button for the first assistant
        @session.first('a', text: 'Chat').click
        sleep 3
        screenshot_path = File.join(@screenshot_dir, "assistant-chat.png")
        screenshot(screenshot_path)
        puts "📸 Captured assistant chat"
        
        # Try to capture a code-related conversation
        if @session.has_css?("textarea", wait: 2)
          @session.fill_in @session.find("textarea")[:name], with: "Can you explain the main components of this codebase and how they interact?"
          sleep 1
          screenshot_path = File.join(@screenshot_dir, "assistant-code-query.png")
          screenshot(screenshot_path)
          puts "📸 Captured assistant code query"
        end
      else
        puts "⚠️  No assistants found for chat screenshot"
      end
    end
    
    step "Capture agent teams" do
      visit "/agent_teams"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "agent-teams.png")
      screenshot(screenshot_path)
      puts "📸 Captured agent teams"
    end
    
    step "Capture knowledge base" do
      visit "/agents/knowledge_documents"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "knowledge-base.png")
      screenshot(screenshot_path)
      puts "📸 Captured knowledge base"
    end
    
    step "Capture chat interface" do
      visit "/chat"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "chat-interface.png")
      screenshot(screenshot_path)
      puts "📸 Captured chat interface"
    end
    
    step "Capture MCP configurations" do
      visit "/mcp_configurations"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "mcp-configs.png")
      screenshot(screenshot_path)
      puts "📸 Captured MCP configurations"
    end
    
    step "Capture Claude Code sessions" do
      # Claude Code is instance-specific, so let's visit an instance first
      visit "/instances"
      if @session.has_css?(".instance-card", wait: 2)
        @session.first(".instance-card").click
        sleep 2
        # Look for Claude Code link/button
        if @session.has_link?("Claude Code", wait: 2)
          @session.click_link("Claude Code")
          sleep 3
          screenshot_path = File.join(@screenshot_dir, "claude-code.png")
          screenshot(screenshot_path)
          puts "📸 Captured Claude Code sessions"
          
          # Try to capture Claude Code chat interface
          if @session.has_css?("textarea", wait: 2) || @session.has_css?("input[type='text']", wait: 2)
            screenshot_path = File.join(@screenshot_dir, "claude-code-chat.png")
            screenshot(screenshot_path)
            puts "📸 Captured Claude Code chat interface"
          end
        elsif @session.has_button?("Claude Code", wait: 2)
          @session.click_button("Claude Code")
          sleep 3
          screenshot_path = File.join(@screenshot_dir, "claude-code.png")
          screenshot(screenshot_path)
          puts "📸 Captured Claude Code sessions"
        else
          # Fallback to instances page
          screenshot_path = File.join(@screenshot_dir, "claude-code.png")
          screenshot(screenshot_path)
          puts "📸 Captured instances (Claude Code fallback)"
        end
      else
        # Fallback to instances page
        visit "/instances"
        sleep 2
        screenshot_path = File.join(@screenshot_dir, "claude-code.png")
        screenshot(screenshot_path)
        puts "📸 Captured instances page (fallback)"
      end
    end
    
    step "Capture integrations" do
      visit "/integrations"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "integrations.png")
      screenshot(screenshot_path)
      puts "📸 Captured integrations"
    end
    
    step "Capture monitoring dashboard" do
      # Try admin monitoring first
      visit "/agents/monitoring"
      if @session.has_content?("Not authorized", wait: 1)
        # Fallback to health check
        visit "/health"
      end
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "monitoring.png")
      screenshot(screenshot_path)
      puts "📸 Captured monitoring"
    end
    
    step "Capture settings/security" do
      visit "/settings"
      sleep 3
      screenshot_path = File.join(@screenshot_dir, "security-settings.png")
      screenshot(screenshot_path)
      puts "📸 Captured settings"
    end
    
    step "Create specific instance views" do
      visit "/instances"
      
      # Try to find an instance to click on
      if @session.has_css?(".instance-card", wait: 2)
        @session.first(".instance-card").click
        sleep 3
        screenshot_path = File.join(@screenshot_dir, "instance-details.png")
        screenshot(screenshot_path)
        puts "📸 Captured instance details"
      else
        puts "⚠️  No instances found for detail screenshot"
      end
    end
    
    step "Create project detail view" do
      visit "/app_projects"
      
      # Try to find a project to click on
      if @session.has_css?(".project-card", wait: 2)
        @session.first(".project-card").click
        sleep 3
        screenshot_path = File.join(@screenshot_dir, "project-details.png")
        screenshot(screenshot_path)
        puts "📸 Captured project details"
      else
        puts "⚠️  No projects found for detail screenshot"
      end
    end
    
    # Summary
    puts "\n📊 Screenshot Summary:"
    puts "━" * 50
    screenshots = Dir[File.join(@screenshot_dir, "*.png")]
    screenshots.each do |file|
      size = File.size(file) / 1024
      puts "✅ #{File.basename(file)} (#{size}KB)"
    end
    puts "━" * 50
    puts "Total screenshots: #{screenshots.count}"
    puts "\nScreenshots saved to: #{@screenshot_dir}"
  end
end

# Auto-run if executed directly
if __FILE__ == $0
  AllsparkProductScreenshotsJourney.new.run_allspark_product_screenshots_journey
end