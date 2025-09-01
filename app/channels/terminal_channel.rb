# frozen_string_literal: true

class TerminalChannel < ApplicationCable::Channel
  # Security: Limit concurrent sessions per user
  MAX_SESSIONS_PER_USER = 3

  # Performance: Rate limiting (adjusted for terminal usage and paste operations)
  RATE_LIMIT_COMMANDS = 5000  # characters per minute (allow for large paste operations)
  RATE_LIMIT_WINDOW = 60      # seconds

  def subscribed
    # Security: Check if user has admin privileges (since terminal access is powerful)
    reject unless current_user&.admin?

    # Security: Check session limits
    if active_sessions_count >= MAX_SESSIONS_PER_USER
      reject
      return
    end

    stream_from "terminal_#{current_user.id}"

    # Start terminal session
    start_terminal_session
  end

  def unsubscribed
    # Clean up terminal session
    cleanup_terminal_session
  end

  def receive(data)
    Rails.logger.info "🔍 Received message type: #{data['type']}"
    case data["type"]
    when "input"
      handle_terminal_input(data)
    when "resize"
      handle_terminal_resize(data)
    when "claude_context"
      handle_claude_context(data)
    when "insert_claude_command"
      Rails.logger.info "🎯 Handling insert_claude_command"
      handle_insert_claude_command(data)
    when "start_development_command"
      Rails.logger.info "🚀 Handling start_development_command"
      handle_start_development_command(data)
    else
      Rails.logger.warn "⚠️ Unknown message type: #{data['type']}"
    end
  end

  private

  def start_terminal_session
    return if @terminal_session

    @terminal_session = TerminalService.create_session(
      user: current_user,
      working_directory: "/app/workspace"
    )

    if @terminal_session
      transmit({
        type: "status",
        status: "Connected"
      })

      # Start reading output
      read_terminal_output
    else
      transmit({
        type: "status",
        status: "Failed to start"
      })
    end
  end

  def cleanup_terminal_session
    if @terminal_session
      TerminalService.cleanup_session(@terminal_session)
      @terminal_session = nil
    end
  end

  def handle_terminal_input(data)
    return unless @terminal_session

    input_data = data["data"]

    # Security: Rate limiting
    return if rate_limited?(input_data)

    # Initialize command buffer if not exists
    @command_buffer ||= ""

    # Add input to buffer
    @command_buffer += input_data

    # Check if we have a complete command (ends with carriage return)
    if input_data.include?("\r")
      # Extract the complete command
      complete_command = @command_buffer.gsub("\r", "").strip

      # Reset buffer for next command
      @command_buffer = ""

      # Security: Command filtering on complete command
      if contains_dangerous_command?(complete_command)
        transmit({
          type: "output",
          data: "\r\n\033[31mCommand blocked for security reasons.\033[0m\r\n"
        })
        return
      end
    end

    # Send all input directly to terminal (no more command interception)
    TerminalService.write_to_session(@terminal_session, input_data)
  end

  def handle_terminal_resize(data)
    return unless @terminal_session

    TerminalService.resize_session(@terminal_session, data["cols"], data["rows"])
  end

  def handle_claude_context(data)
    project_id = data["project_id"]

    begin
      Rails.logger.info "🔍 Loading Claude context for project: #{project_id}"
      # Try to find by ID first, then by slug if that fails
      app_project = current_user.app_projects.find_by(id: project_id) ||
                   current_user.app_projects.find_by(slug: project_id)

      if app_project
        Rails.logger.info "✅ Found project: #{app_project.name}"
        ClaudeContextService.prepare_context(app_project)
        transmit({
          type: "claude_context",
          loaded: true
        })
      else
        Rails.logger.warn "❌ Project not found: #{project_id}"
        transmit({
          type: "claude_context",
          loaded: false
        })
      end
    rescue => e
      Rails.logger.error "💥 Error loading Claude context: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      transmit({
        type: "claude_context",
        loaded: false
      })
    end
  end

  def handle_insert_claude_command(data)
    return unless @terminal_session

    project_id = data["project_id"]

    begin
      Rails.logger.info "🔍 Inserting Claude command for project: #{project_id}"
      # Try to find by ID first, then by slug if that fails
      app_project = current_user.app_projects.find_by(id: project_id) ||
                   current_user.app_projects.find_by(slug: project_id)

      if app_project
        Rails.logger.info "✅ Found project: #{app_project.name}"

        # Prepare context and get enhanced command
        ClaudeContextService.prepare_context(app_project)
        enhanced_command = ClaudeContextService.enhance_command("claude", app_project)

        # Insert the enhanced command into the terminal
        TerminalService.write_to_session(@terminal_session, enhanced_command)

        Rails.logger.info "📝 Inserted command: #{enhanced_command}"
      else
        Rails.logger.warn "❌ Project not found: #{project_id}"
        # Insert basic claude command as fallback
        TerminalService.write_to_session(@terminal_session, "claude")
      end
    rescue => e
      Rails.logger.error "💥 Error inserting Claude command: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Insert basic claude command as fallback
      TerminalService.write_to_session(@terminal_session, "claude")
    end
  end

  def handle_start_development_command(data)
    return unless @terminal_session

    project_id = data["project_id"]

    begin
      Rails.logger.info "🚀 Starting development for project: #{project_id}"
      # Try to find by ID first, then by slug if that fails
      app_project = current_user.app_projects.find_by(id: project_id) ||
                   current_user.app_projects.find_by(slug: project_id)

      if app_project && app_project.generated_prd.present? && app_project.generated_tasks.present?
        Rails.logger.info "✅ Found project with PRD and tasks: #{app_project.name}"

        # First, copy project files to workspace
        ClaudeContextService.copy_to_workspace(app_project)

        # Build the development command with all required documentation
        development_command = build_development_command(app_project)

        # Insert the development command into the terminal
        TerminalService.write_to_session(@terminal_session, development_command)

        Rails.logger.info "🚀 Inserted development command: #{development_command}"
      else
        Rails.logger.warn "❌ Project not found or missing PRD/tasks: #{project_id}"
        # Insert basic claude command as fallback
        TerminalService.write_to_session(@terminal_session, "claude --dangerously-skip-permissions")
      end
    rescue => e
      Rails.logger.error "💥 Error starting development: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Insert basic claude command as fallback
      TerminalService.write_to_session(@terminal_session, "claude --dangerously-skip-permissions")
    end
  end

  def build_development_command(app_project)
    # Create a comprehensive prompt that references the documentation in the workspace
    prompt = <<~PROMPT.strip
      I'm starting development on #{app_project.name}. Please:

      1. Read the PRD at docs/app-projects/generated/#{app_project.id}/prd.md to understand the product requirements
      2. Review the task list at docs/app-projects/generated/#{app_project.id}/tasks.md for implementation steps
      3. Check the README.md in this workspace to understand the project context
      4. Review the main Rails template documentation to understand available generators
      5. Begin implementing the features step by step following the task breakdown

      You're now working in the /app/workspace directory which contains all the project documentation. Use the Rails generators extensively (rails g scaffold, rails g service, rails g ui_component) as outlined in the documentation. This template is optimized for rapid development with AI assistance.

      Start by confirming you can access the documentation files in docs/, then begin with the first tasks in the development plan.
    PROMPT

    # Build the Claude Code command with the prompt
    escaped_prompt = prompt.gsub('"', '\\"').gsub("\n", "\\n")
    "claude --dangerously-skip-permissions \"#{escaped_prompt}\""
  end


  def read_terminal_output
    return unless @terminal_session

    # This will be handled by the TerminalService
    # which will broadcast output to the channel
    TerminalService.setup_output_streaming(@terminal_session, current_user.id)
  end

  def active_sessions_count
    TerminalService.sessions_for_user(current_user.id).count
  end

  def rate_limited?(input_data = "")
    now = Time.current
    @character_log ||= []

    # Remove old entries outside the window
    @character_log.reject! { |entry| entry[:timestamp] < now - RATE_LIMIT_WINDOW }

    # Count characters in current window
    current_char_count = @character_log.sum { |entry| entry[:chars] }

    # Allow burst for paste operations (if input is large, it's likely a paste)
    is_paste_operation = input_data.length > 100
    effective_limit = is_paste_operation ? RATE_LIMIT_COMMANDS * 2 : RATE_LIMIT_COMMANDS

    # Check if adding this input would exceed the limit
    if current_char_count + input_data.length > effective_limit
      message = is_paste_operation ?
        "\r\n\033[33mLarge paste operation rate limited. Try breaking it into smaller chunks.\033[0m\r\n" :
        "\r\n\033[33mRate limit exceeded. Please slow down your typing.\033[0m\r\n"

      transmit({
        type: "output",
        data: message
      })
      return true
    end

    # Add current input to log
    @character_log << { timestamp: now, chars: input_data.length }
    false
  end

  def contains_dangerous_command?(input)
    dangerous_patterns = [
      /rm\s+-rf\s+\//, # rm -rf /
      /sudo\s+rm\s+-rf/, # sudo rm -rf
      /:\(\)\{.*;\}/, # fork bomb
      /chmod\s+777\s+\//, # chmod 777 /
      /dd\s+if=.*of=\/dev/, # dd to system devices
      /mkfs/, # format filesystem
      /fdisk/, # disk partitioning
      /crontab\s+-r/, # remove all cron jobs
      /killall\s+-9/, # kill all processes
      /shutdown/, # system shutdown
      /reboot/, # system reboot
      /halt/, # system halt
      /init\s+0/, # shutdown
      /init\s+6/, # reboot
      /\/etc\/passwd/, # password file
      /\/etc\/shadow/, # shadow file
      /systemctl\s+stop/, # stop system services
      /service\s+.*\s+stop/, # stop services
      /docker\s+rm/, # remove docker containers
      /docker\s+rmi/ # remove docker images
    ]

    dangerous_patterns.any? { |pattern| input.match?(pattern) }
  end
end
