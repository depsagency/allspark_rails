# frozen_string_literal: true

require_relative '../base_journey'

class UserRegistrationJourney < BaseJourney
  include JourneyHelper

  journey :user_registration do
    setup_session

    begin
      step "Visit home page" do
        visit "/"
        expect_no_errors
        screenshot("home_page")
      end

      step "Navigate to sign in page" do
        click_link "Sign In" if @session.has_link?("Sign In")
        expect_page_to_have("Sign in to your account")
        expect_no_errors
      end

      step "Navigate to registration page" do
        click_link "Create a new account"
        expect_page_to_have("Create your account")
        expect_no_errors
        screenshot("registration_page")
      end

      step "Fill in registration form" do
        user_data = test_user_data
        
        # Use model field names instead of label text
        fill_in "user_first_name", with: "Test"
        fill_in "user_last_name", with: "User"
        fill_in "user_email", with: user_data[:email]
        fill_in "user_password", with: user_data[:password]
        fill_in "user_password_confirmation", with: user_data[:password_confirmation]
        
        screenshot("registration_form_filled")
      end

      step "Submit registration" do
        click_button "Create Account"
        wait_for_turbo
      end

      step "Verify successful registration" do
        # Check for success message or redirect
        if @session.has_content?("Welcome! You have signed up successfully.")
          expect_success("Registration successful!")
        elsif @session.has_content?("A message with a confirmation link")
          expect_success("Registration successful - confirmation email sent!")
        else
          # Check if we're logged in by looking for logout link
          if @session.has_link?("Logout") || @session.has_button?("Logout")
            expect_success("Registration successful - user logged in!")
          else
            raise "Registration may have failed - no success indicators found"
          end
        end
        
        expect_no_errors
        screenshot("registration_complete")
      end

      step "Verify user can access authenticated pages" do
        visit "/users/edit" if @session.has_link?("Profile") || @session.current_path != "/users/edit"
        
        if @session.current_path == "/users/sign_in"
          raise "User not authenticated after registration"
        else
          expect_success("User can access authenticated pages")
        end
      end

    ensure
      teardown_session
    end
  end
end