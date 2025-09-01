# frozen_string_literal: true

require "pty"
require "io/console"

class TerminalService
  class << self
    def create_session(user:, working_directory: "/workspace")
      session_id = SecureRandom.uuid

      begin
        # Connect to Builder container to work in /workspace (Target's /app)
        container_name = find_builder_container
        
        unless container_name
          Rails.logger.error "Builder container not found"
          return nil
        end

        # Use Docker exec to create a PTY session in the Builder container
        master, slave = PTY.open

        # Set terminal size for proper formatting (especially for Claude Code)
        master.winsize = [ 25, 120 ]  # rows, cols - wide enough for Claude Code

        # Execute bash in the Builder container with PTY
        docker_command = [
          "docker", "exec", "-it", 
          container_name,
          "/bin/bash", "-c", 
          "cd #{working_directory} && exec /bin/bash"
        ]

        pid = spawn(*docker_command, in: slave, out: slave, err: slave)

        # Close the slave end in the parent process
        slave.close

        # Store session data
        session = {
          id: session_id,
          user_id: user.id,
          master: master,
          pid: pid,
          container_name: container_name,
          working_directory: working_directory,
          created_at: Time.current
        }

        # Store in class variable for now (in production, use Redis)
        sessions[session_id] = session

        # Start output reading thread
        start_output_thread(session)

        session_id
      rescue => e
        Rails.logger.error "Failed to create terminal session: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    def write_to_session(session_id, data)
      session = sessions[session_id]
      return false unless session

      begin
        session[:master].write(data)
        true
      rescue => e
        Rails.logger.error "Failed to write to terminal session #{session_id}: #{e.message}"
        false
      end
    end

    def resize_session(session_id, cols, rows)
      session = sessions[session_id]
      return false unless session

      begin
        session[:master].winsize = [ rows, cols ]
        true
      rescue => e
        Rails.logger.error "Failed to resize terminal session #{session_id}: #{e.message}"
        false
      end
    end

    def cleanup_session(session_id)
      session = sessions[session_id]
      return false unless session

      begin
        # Kill the process
        Process.kill("TERM", session[:pid])

        # Close the master PTY
        session[:master].close unless session[:master].closed?

        # Wait for process to exit
        Process.wait(session[:pid])
      rescue => e
        Rails.logger.error "Error cleaning up terminal session #{session_id}: #{e.message}"
      ensure
        # Remove from sessions
        sessions.delete(session_id)
      end

      true
    end

    def setup_output_streaming(session_id, user_id)
      # Output streaming is handled by the output thread started in create_session
      # This method exists for compatibility with the channel
      true
    end

    def sessions_for_user(user_id)
      sessions.select { |_id, session| session[:user_id] == user_id }
    end

    private

    def sessions
      @sessions ||= {}
    end

    def find_builder_container
      # Find the Builder container by looking for containers with "builder" in the name
      # Exclude builder-sidekiq containers
      output = `docker ps --format "{{.Names}}" | grep -E "builder-[0-9]+" 2>/dev/null`.strip.split("\n").first
      
      if output.blank?
        # Fallback: look for containers with compose service label
        output = `docker ps --filter "label=com.docker.compose.service=builder" --format "{{.Names}}" 2>/dev/null`.strip
      end
      
      Rails.logger.info "Found builder container: #{output}" if output.present?
      output.present? ? output : nil
    end
    
    def find_target_container
      # Find the Target container by looking for containers with "target" in the name
      output = `docker ps --format "{{.Names}}" | grep target 2>/dev/null`.strip.split("\n").first
      
      if output.blank?
        # Fallback: look for containers with compose service label
        output = `docker ps --filter "label=com.docker.compose.service=target" --format "{{.Names}}" 2>/dev/null`.strip
      end
      
      Rails.logger.info "Found target container: #{output}" if output.present?
      output.present? ? output : nil
    end

    def shell_command
      # Use bash with login shell to load user environment
      if RUBY_PLATFORM.include?("darwin") || RUBY_PLATFORM.include?("linux")
        "/bin/bash --login"
      else
        "/bin/sh"
      end
    end

    def start_output_thread(session)
      Thread.new do
        begin
          loop do
            # Check if process is still alive
            unless process_alive?(session[:pid])
              break
            end

            # Read available data (non-blocking)
            ready = IO.select([ session[:master] ], nil, nil, 0.1)

            if ready && ready[0].include?(session[:master])
              begin
                data = session[:master].read_nonblock(4096)

                # Broadcast to the user's terminal channel
                ActionCable.server.broadcast(
                  "terminal_#{session[:user_id]}",
                  {
                    type: "output",
                    data: data
                  }
                )
              rescue IO::WaitReadable
                # No data available, continue
              rescue EOFError
                # Process ended
                break
              end
            end
          end
        rescue => e
          Rails.logger.error "Terminal output thread error: #{e.message}"
        ensure
          # Clean up session when thread exits
          cleanup_session(session[:id])

          # Notify user of disconnection
          ActionCable.server.broadcast(
            "terminal_#{session[:user_id]}",
            {
              type: "status",
              status: "Disconnected"
            }
          )
        end
      end
    end

    def process_alive?(pid)
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end
  end
end
