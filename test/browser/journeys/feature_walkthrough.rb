# frozen_string_literal: true

require_relative '../base_journey'

class FeatureWalkthroughJourney < BaseJourney
  include JourneyHelper

  journey :feature_walkthrough do
    setup_session

    begin
      step "Login as admin" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end

      step "Explore navigation menu" do
        visit "/"
        
        # Check for common navigation elements
        navigation_items = []
        
        # Check different possible navigation patterns
        if @session.has_css?("nav")
          within("nav") do
            navigation_items = @session.all("a").map(&:text).reject(&:blank?)
          end
        elsif @session.has_css?(".navbar")
          within(".navbar") do
            navigation_items = @session.all("a").map(&:text).reject(&:blank?)
          end
        elsif @session.has_css?("[data-controller='navbar']")
          within("[data-controller='navbar']") do
            navigation_items = @session.all("a").map(&:text).reject(&:blank?)
          end
        end
        
        puts "  Found navigation items: #{navigation_items.join(', ')}"
        expect_success("Navigation menu explored")
      end

      step "Check theme switching" do
        # Look for theme switcher
        if @session.has_css?("[data-theme-switcher]") || @session.has_button?("Toggle theme")
          if @session.has_button?("Toggle theme")
            click_button "Toggle theme"
          else
            @session.find("[data-theme-switcher]").click
          end
          
          sleep 0.5
          expect_success("Theme switcher works")
        else
          puts "  Theme switcher not found - skipping"
        end
      end

      step "Visit user management" do
        if @session.has_link?("Users")
          click_link "Users"
          wait_for_turbo
          expect_page_to_have("Users")
          expect_no_errors
          screenshot("users_page")
          
          # Check for user list
          if @session.has_css?("table") || @session.has_css?(".user-list")
            expect_success("User list displayed")
          end
        else
          puts "  Users link not found - trying direct navigation"
          visit "/users"
          if @session.current_path == "/users"
            expect_success("Users page accessible via direct URL")
          else
            puts "  Users management not accessible"
          end
        end
      end

      step "Test responsive design" do
        # Test mobile view
        @session.driver.resize_window(375, 667)
        sleep 0.5
        screenshot("mobile_view")
        
        # Check if mobile menu appears
        if @session.has_css?(".mobile-menu") || @session.has_css?("[data-mobile-menu]")
          expect_success("Mobile menu present")
        end
        
        # Test tablet view
        @session.driver.resize_window(768, 1024)
        sleep 0.5
        screenshot("tablet_view")
        
        # Reset to desktop
        @session.driver.resize_window(1200, 800)
        expect_success("Responsive design tested")
      end

      step "Check for real-time features" do
        if @session.has_link?("Live Demo") || @session.has_link?("Real-time")
          visit "/live_demo" rescue visit "/realtime"
          
          if @session.has_content?("Real-time Features")
            expect_success("Real-time features page found")
            screenshot("realtime_features")
          end
        else
          puts "  Real-time features demo not found"
        end
      end

      step "Test search functionality" do
        visit "/"
        
        if @session.has_field?("search") || @session.has_field?("q")
          search_field = @session.has_field?("search") ? "search" : "q"
          fill_in search_field, with: "test"
          
          # Submit search
          if @session.has_button?("Search")
            click_button "Search"
          else
            @session.find_field(search_field).native.send_keys(:return)
          end
          
          wait_for_turbo
          expect_success("Search functionality tested")
        else
          puts "  Search functionality not found"
        end
      end

      step "Check footer information" do
        if @session.has_css?("footer")
          within("footer") do
            footer_text = @session.text
            puts "  Footer contains: #{footer_text.split("\n").first(2).join(', ')}"
          end
          expect_success("Footer present")
        end
      end

      step "Final health check" do
        visit "/"
        expect_no_errors
        screenshot("final_homepage")
        expect_success("Application walkthrough completed successfully!")
      end

    ensure
      teardown_session
    end
  end
end