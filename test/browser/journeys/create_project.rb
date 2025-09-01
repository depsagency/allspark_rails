# frozen_string_literal: true

require_relative '../base_journey'

class CreateProjectJourney < BaseJourney
  include JourneyHelper

  journey :create_project do
    setup_session

    begin
      step "Login as admin" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end

      step "Navigate to app projects" do
        visit "/app_projects"
        
        # Handle different possible UI patterns
        if @session.has_content?("App Projects")
          expect_success("On app projects page")
        elsif @session.has_content?("Projects")
          expect_success("On projects page")
        else
          # Try to find it in navigation
          if @session.has_link?("App Projects")
            click_link "App Projects"
          elsif @session.has_link?("Projects")
            click_link "Projects"
          else
            raise "Cannot find app projects page"
          end
        end
        
        expect_no_errors
        screenshot("app_projects_index")
      end

      step "Start creating new project" do
        # Look for various possible button texts
        if @session.has_link?("New App Project")
          click_link "New App Project"
        elsif @session.has_link?("New Project")
          click_link "New Project"
        elsif @session.has_button?("Create New Project")
          click_button "Create New Project"
        elsif @session.has_link?("Create App Project")
          click_link "Create App Project"
        else
          # Try the direct URL
          visit "/app_projects/new"
        end
        
        wait_for_turbo
        expect_no_errors
      end

      step "Fill in project questionnaire" do
        # Check if we're on the questionnaire or a different form
        if @session.has_content?("What is your app idea?")
          # Questionnaire format
          fill_in_questionnaire
        else
          # Standard form format
          fill_in_standard_form
        end
        
        screenshot("project_form_filled")
      end

      step "Submit project" do
        # Find and click the submit button
        if @session.has_button?("Create App project")
          click_button "Create App project"
        elsif @session.has_button?("Create Project")
          click_button "Create Project"
        elsif @session.has_button?("Generate PRD")
          click_button "Generate PRD"
        elsif @session.has_button?("Submit")
          click_button "Submit"
        else
          raise "Cannot find submit button"
        end
        
        wait_for_turbo
        
        # Wait a bit longer for processing
        sleep 2
      end

      step "Verify project creation" do
        # Check for various success indicators
        if @session.has_content?("successfully created")
          expect_success("Project created successfully!")
        elsif @session.has_content?("PRD generated")
          expect_success("PRD generated successfully!")
        elsif @session.current_path.match?(/\/app_projects\/\d+/)
          expect_success("Redirected to project page")
        else
          # Check if we're on a project page by looking for project details
          if @session.has_content?("Project Details") || @session.has_content?("Implementation Plan")
            expect_success("Project appears to be created")
          else
            screenshot("project_creation_result")
            raise "Project creation status unclear"
          end
        end
        
        expect_no_errors
        screenshot("project_created")
      end

    ensure
      teardown_session
    end
  end

  private

  def fill_in_questionnaire
    # Fill in the questionnaire fields
    questions = {
      "What is your app idea?" => "A task management app for remote teams",
      "Who are your target users?" => "Remote workers and distributed teams",
      "What problem does it solve?" => "Helps teams stay organized and communicate effectively",
      "What are the key features?" => "Task boards, real-time updates, team chat, time tracking",
      "Do you have any technical requirements?" => "Must work on mobile and desktop, real-time sync",
      "What is your timeline?" => "MVP in 2 months",
      "What is your budget?" => "$10,000",
      "Do you have design preferences?" => "Clean, modern, minimal design",
      "Any additional notes?" => "Integration with Slack would be nice"
    }

    questions.each do |question, answer|
      if @session.has_field?(question)
        fill_in question, with: answer
      elsif @session.has_css?("label", text: question)
        # Find the field by its label
        label = @session.find("label", text: question)
        field_id = label[:for]
        if field_id && @session.has_field?(field_id)
          fill_in field_id, with: answer
        end
      end
    end
  end

  def fill_in_standard_form
    # Fill in standard form fields
    if @session.has_field?("Name")
      fill_in "Name", with: "Task Management App"
    end
    
    if @session.has_field?("Description")
      fill_in "Description", with: "A comprehensive task management solution for remote teams"
    end
    
    if @session.has_field?("app_project_name")
      fill_in "app_project_name", with: "Task Management App"
    end
    
    if @session.has_field?("app_project_description")
      fill_in "app_project_description", with: "A comprehensive task management solution for remote teams"
    end
  end
end