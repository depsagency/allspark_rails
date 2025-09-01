# frozen_string_literal: true

require_relative '../base_journey'

class UserLoginJourney < BaseJourney
  include JourneyHelper

  journey :user_login do
    setup_session

    begin
      step "Visit home page" do
        visit "/"
        expect_no_errors
      end

      step "Navigate to login page" do
        if @session.has_link?("Sign in")
          click_link "Sign in"
        else
          visit "/users/sign_in"
        end
        
        expect_page_to_have("Log in")
        expect_no_errors
      end

      step "Attempt login with invalid credentials" do
        fill_in "Email", with: "invalid@example.com"
        fill_in "Password", with: "wrongpassword"
        click_button "Log in"
        wait_for_turbo
        
        expect_page_to_have("Invalid Email or password")
        expect_success("Invalid login correctly rejected")
      end

      step "Login with valid credentials" do
        # Use the default admin account from seeds
        fill_in "Email", with: "admin@example.com"
        fill_in "Password", with: "password123"
        
        screenshot("login_form_filled")
        click_button "Log in"
        wait_for_turbo
      end

      step "Verify successful login" do
        if @session.has_content?("Signed in successfully")
          expect_success("Login successful!")
        elsif @session.has_link?("Logout") || @session.has_button?("Logout")
          expect_success("User successfully authenticated!")
        else
          raise "Login may have failed - no success indicators found"
        end
        
        expect_no_errors
        screenshot("login_successful")
      end

      step "Navigate to protected area" do
        # Try to access user profile
        if @session.has_link?("Profile")
          click_link "Profile"
        else
          visit "/users/edit"
        end
        
        # Should not be redirected to login
        if @session.current_path == "/users/sign_in"
          raise "User not properly authenticated"
        else
          expect_success("Can access protected areas")
        end
      end

      step "Logout" do
        logout
        expect_no_errors
      end

      step "Verify logout" do
        visit "/users/edit"
        
        # Should be redirected to login
        if @session.current_path == "/users/sign_in"
          expect_success("Logout successful - protected pages require authentication")
        else
          raise "User may still be logged in after logout"
        end
      end

    ensure
      teardown_session
    end
  end
end