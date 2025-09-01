require "test_helper"

class AppProjects::ImporterServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      role: "system_admin"
    )
    @project_folder_id = "6f935deb-6d01-4363-9e25-7e44167271c4"
    @project_dir = Rails.root.join("docs/app-projects/generated/#{@project_folder_id}")

    # Create test project directory structure
    create_test_project_structure
  end

  teardown do
    # Clean up test directory
    FileUtils.rm_rf(@project_dir) if Dir.exist?(@project_dir)
  end

  test "should list available projects" do
    available_projects = AppProjects::ImporterService.list_available_projects

    assert available_projects.is_a?(Array)
    project = available_projects.find { |p| p[:project_id] == @project_folder_id }

    assert_not_nil project
    assert_equal "Test Pirate Ship Simulator", project[:project_name]
    assert project[:can_import]
  end

  test "should preview project successfully" do
    importer = AppProjects::ImporterService.new(@project_folder_id, current_user: @user)
    preview = importer.preview

    assert preview[:can_import]
    assert_equal @project_folder_id, preview[:project_id]
    assert_equal "Test Pirate Ship Simulator", preview[:project_name]
    assert_equal "test-pirate-ship-simulator", preview[:slug]
    assert_equal "completed", preview[:status]
    assert_equal 100, preview[:completion_percentage]

    assert preview[:files_available].is_a?(Array)
    assert preview[:artifacts_available].is_a?(Array)

    # Check for essential files
    file_names = preview[:files_available].map { |f| f[:name] }
    assert_includes file_names, "metadata.json"
    assert_includes file_names, "user-input.md"
  end

  test "should import project successfully" do
    importer = AppProjects::ImporterService.new(@project_folder_id, current_user: @user)

    assert_difference "AppProject.count", 1 do
      imported_project = importer.import!

      assert_not_nil imported_project
      assert_equal "Test Pirate Ship Simulator", imported_project.name
      assert_equal "test-pirate-ship-simulator", imported_project.slug
      assert_equal "completed", imported_project.status
      assert_equal @user, imported_project.user

      # Check that user responses were imported
      assert_not_nil imported_project.vision_response
      assert_includes imported_project.vision_response, "pirate ship simulator"

      # Check that generated content was imported
      assert_not_nil imported_project.generated_prd
      assert_includes imported_project.generated_prd, "Pirate Ship Simulator"
    end
  end

  test "should handle missing metadata gracefully" do
    # Create directory without metadata.json
    test_dir = Rails.root.join("docs/app-projects/generated/missing-metadata")
    FileUtils.mkdir_p(test_dir)

    begin
      importer = AppProjects::ImporterService.new("missing-metadata", current_user: @user)

      assert_raises AppProjects::ImporterService::ImportError do
        importer.import!
      end
    ensure
      FileUtils.rm_rf(test_dir)
    end
  end

  test "should handle overwrite existing project" do
    # First import
    importer1 = AppProjects::ImporterService.new(@project_folder_id, current_user: @user)
    first_project = importer1.import!

    # Second import with overwrite
    importer2 = AppProjects::ImporterService.new(
      @project_folder_id,
      current_user: @user,
      options: { overwrite_existing: true }
    )

    assert_no_difference "AppProject.count" do
      second_project = importer2.import!
      assert_equal first_project.id, second_project.id
    end
  end

  test "should prevent duplicate import without overwrite" do
    # First import
    importer1 = AppProjects::ImporterService.new(@project_folder_id, current_user: @user)
    importer1.import!

    # Second import without overwrite should fail
    importer2 = AppProjects::ImporterService.new(@project_folder_id, current_user: @user)

    assert_raises AppProjects::ImporterService::ImportError do
      importer2.import!
    end
  end

  private

  def create_test_project_structure
    FileUtils.mkdir_p(@project_dir)
    FileUtils.mkdir_p(@project_dir.join("artifacts"))

    # Create metadata.json
    metadata = {
      "project_id" => @project_folder_id,
      "generated_at" => "2025-06-27T03:34:06Z",
      "generation_version" => "1.0",
      "user_id" => @user.id,
      "session_data" => {
        "completion_percentage" => 100,
        "questions_answered" => 10,
        "total_questions" => 10,
        "ready_for_generation" => true
      },
      "project_metadata" => {
        "name" => "Test Pirate Ship Simulator",
        "slug" => "test-pirate-ship-simulator",
        "status" => "completed",
        "created_at" => "2025-06-24T04:04:12Z",
        "updated_at" => "2025-06-27T03:33:49Z"
      },
      "files_generated" => [
        "prd.md",
        "tasks.md",
        "user-input.md",
        "claude-context.md",
        "metadata.json"
      ]
    }

    File.write(@project_dir.join("metadata.json"), JSON.pretty_generate(metadata))

    # Create user-input.md
    user_input = <<~MARKDOWN
      # User Input: Test Pirate Ship Simulator

      Generated: 2025-06-27 03:19:57 UTC
      Project ID: #{@project_folder_id}
      Completion: 100%

      ## Application Vision
      I want to build a pirate ship simulator where players can sail the seas, engage in battles, and manage their crew.

      ## Target Users
      Gamers who enjoy simulation and strategy games, particularly those interested in pirate themes.

      ## User Journeys
      Players create a character, join a crew, sail to different ports, complete missions, and advance through ranks.

      ## Core Features
      Ship management, crew management, trading, combat, exploration, character progression.

      ## Technical Requirements
      Web-based game with real-time multiplayer capabilities, 3D graphics, and persistent world.

      ## Third-party Integrations
      Payment processing for premium features, social media integration for sharing achievements.

      ## Success Metrics
      Daily active users, session length, revenue from premium features.

      ## Competition Analysis
      Similar to games like Sea of Thieves but browser-based and more accessible.

      ## Design Requirements
      Pirate-themed UI with nautical elements, responsive design for desktop and mobile.

      ## Challenges & Concerns
      Real-time multiplayer synchronization, balancing gameplay mechanics, server costs.
    MARKDOWN

    File.write(@project_dir.join("user-input.md"), user_input)

    # Create PRD
    prd_content = <<~MARKDOWN
      # Product Requirements Document: Test Pirate Ship Simulator

      ## Executive Summary
      A browser-based pirate ship simulator game where players manage ships, crews, and engage in maritime adventures.

      ## Features
      - Ship customization and management
      - Crew recruitment and management
      - Real-time sailing and combat
      - Trading and economy system
      - Character progression

      ## Technical Requirements
      - Web-based application
      - Real-time multiplayer
      - 3D graphics rendering
      - Persistent game world
    MARKDOWN

    File.write(@project_dir.join("prd.md"), prd_content)

    # Create tasks.md
    tasks_content = <<~MARKDOWN
      # Development Tasks: Test Pirate Ship Simulator

      ## Phase 1: Foundation
      - Set up development environment
      - Create basic game architecture
      - Implement user authentication

      ## Phase 2: Core Gameplay
      - Develop ship mechanics
      - Implement crew management
      - Create basic combat system

      ## Phase 3: Features
      - Add trading system
      - Implement character progression
      - Create multiplayer functionality
    MARKDOWN

    File.write(@project_dir.join("tasks.md"), tasks_content)
  end
end
