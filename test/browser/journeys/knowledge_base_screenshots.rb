# frozen_string_literal: true

require_relative '../base_journey'

class KnowledgeBaseScreenshotsJourney < BaseJourney
  include JourneyHelper

  def initialize
    super
    @screenshots_dir = Rails.root.join('docs/user-guides/knowledge-base/screenshots')
    FileUtils.mkdir_p(@screenshots_dir)
  end

  journey :knowledge_base_screenshots do
    setup_session

    begin
      # Login first
      login_as('demo@example.com', 'password123')
      
      # 1. Knowledge Base Index
      visit "/agents/knowledge_documents"
      wait_for_page_load
      save_screenshot("01_knowledge_base_index")
      
      # 2. Show filters
      if @session.has_content?("Filters")
        @session.find('summary', text: 'Filters').click
        wait_for_animation
        save_screenshot("02_filters_expanded")
      end
      
      # 3. Search
      fill_in "query", with: "API authentication"
      click_button "Search"
      wait_for_page_load
      save_screenshot("03_search_results")
      
      # 4. Clear and go to new document
      visit "/agents/knowledge_documents"
      wait_for_page_load
      click_link "Upload Document"
      wait_for_page_load
      save_screenshot("04_new_document_form")
      
      # 5. Fill form
      fill_in "Title", with: "API Integration Guide"
      fill_in "knowledge_document[content]", with: "This guide covers API integration best practices."
      fill_in "Tags", with: "api, integration, guide"
      fill_in "Category", with: "Technical Documentation"
      fill_in "Project", with: "Developer Portal"
      
      if @session.has_select?("Visibility")
        select "Team (All team members)", from: "Visibility"
      end
      
      save_screenshot("05_form_filled")
      
      # 6. View document
      visit "/agents/knowledge_documents"
      wait_for_page_load
      @session.first('a.link-hover').click
      wait_for_page_load
      save_screenshot("06_document_view")
      
      # 7. Edit
      if @session.has_link?("Edit")
        click_link "Edit"
        wait_for_page_load
        save_screenshot("07_edit_form")
      end
      
      puts "\n✅ All screenshots saved to: #{@screenshots_dir}"
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    ensure
      teardown_session
    end
  end

  private

  def wait_for_page_load
    sleep 2
  end

  def wait_for_animation
    sleep 1
  end

  def save_screenshot(filename)
    path = @screenshots_dir.join("#{filename}.png")
    @session.save_screenshot(path.to_s)
    puts "📸 Saved: #{filename}.png"
  end
end