# frozen_string_literal: true

namespace :knowledge_base do
  desc "Generate screenshots for knowledge base documentation"
  task screenshots: :environment do
    require 'capybara'
    require 'capybara/cuprite'
    
    # Configure Capybara
    Capybara.register_driver :cuprite do |app|
      Capybara::Cuprite::Driver.new(
        app, 
        headless: true,
        js_errors: false,
        timeout: 30,
        process_timeout: 30,
        browser_options: {
          'no-sandbox' => nil,
          'disable-dev-shm-usage' => nil,
          'disable-gpu' => nil
        }
      )
    end
    
    Capybara.app_host = "http://localhost:3000"
    session = Capybara::Session.new(:cuprite)
    
    # Create screenshots directory
    screenshots_dir = Rails.root.join('docs/user-guides/knowledge-base/screenshots')
    FileUtils.mkdir_p(screenshots_dir)
    
    puts "📸 Generating Knowledge Base screenshots..."
    
    begin
      # Login
      session.visit "/users/sign_in"
      session.fill_in "user[email]", with: "demo@example.com"
      session.fill_in "user[password]", with: "password123"
      session.click_button "Sign in"
      sleep 2
      
      # 1. Knowledge Base Index
      session.visit "/agents/knowledge_documents"
      sleep 2
      session.save_screenshot(screenshots_dir.join("01_knowledge_base_index.png").to_s)
      puts "✓ Saved: 01_knowledge_base_index.png"
      
      # 2. Filters expanded
      if session.has_content?("Filters")
        session.find('summary', text: 'Filters').click
        sleep 1
        session.save_screenshot(screenshots_dir.join("02_filters_expanded.png").to_s)
        puts "✓ Saved: 02_filters_expanded.png"
      end
      
      # 3. New Document Form
      session.visit "/agents/knowledge_documents/new"
      sleep 2
      session.save_screenshot(screenshots_dir.join("03_new_document_form.png").to_s)
      puts "✓ Saved: 03_new_document_form.png"
      
      # 4. Fill form
      session.fill_in "Title", with: "API Integration Guide"
      session.fill_in "knowledge_document[content]", with: "This guide covers API integration best practices including authentication, error handling, and rate limiting."
      session.fill_in "Tags", with: "api, integration, authentication, best-practices"
      session.fill_in "Category", with: "Technical Documentation"
      session.fill_in "Project", with: "Developer Portal"
      
      if session.has_select?("Visibility")
        session.select "Team", from: "Visibility"
      end
      
      if session.has_select?("Priority")
        session.select "High", from: "Priority"
      end
      
      sleep 1
      session.save_screenshot(screenshots_dir.join("04_form_filled.png").to_s)
      puts "✓ Saved: 04_form_filled.png"
      
      # 5. Document view (if any exist)
      session.visit "/agents/knowledge_documents"
      sleep 2
      
      if session.has_css?('a.link-hover')
        session.first('a.link-hover').click
        sleep 2
        session.save_screenshot(screenshots_dir.join("05_document_view.png").to_s)
        puts "✓ Saved: 05_document_view.png"
        
        # 6. Edit form
        if session.has_link?("Edit")
          session.click_link "Edit"
          sleep 2
          session.save_screenshot(screenshots_dir.join("06_edit_form.png").to_s)
          puts "✓ Saved: 06_edit_form.png"
        end
      end
      
      puts "\n✅ All screenshots saved to: #{screenshots_dir}"
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    ensure
      session.quit
    end
  end
end