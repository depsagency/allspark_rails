# Debug session handling in development - TEMPORARILY DISABLED TO FIX BOOT LOOP
if false && Rails.env.development?
  Rails.application.config.after_initialize do
    ActionDispatch::Request.class_eval do
      alias_method :original_session, :session
      
      def session
        result = original_session
        if path =~ /sign_in|sessions/
          Rails.logger.info "[SESSION] Request to #{path}"
          Rails.logger.info "[SESSION] Session ID: #{result.id}"
          Rails.logger.info "[SESSION] Session loaded: #{result.loaded?}"
          Rails.logger.info "[SESSION] Cookie header: #{headers['Cookie']}"
          Rails.logger.info "[SESSION] Referer: #{referer}"
        end
        result
      end
    end
  end
end
