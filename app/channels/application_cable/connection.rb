module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # In development/test, we can use session-based auth
      # In production, you might want to use token-based auth
      if verified_user = env['warden'].user
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def session
      # Access the session from the request
      @session ||= request.session
    end
  end
end
