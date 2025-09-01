# DevTools Configuration for Target Applications
# Middleware to enable AllSpark Builder DevTools monitoring
#
# This middleware:
# 1. Sets proper HTTP headers for iframe embedding in DevTools
# 2. Configures CORS for cross-origin postMessage communication
# 3. Removes restrictive headers that would block DevTools
#
# The actual monitoring JavaScript is in app/javascript/devtools_monitor.js

class DevToolsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Add DevTools-specific headers
    if devtools_enabled?
      # Remove X-Frame-Options to allow iframe embedding
      headers.delete('X-Frame-Options')
      headers.delete('x-frame-options') # Handle lowercase variant
      
      # Set permissive Content Security Policy for DevTools
      headers['Content-Security-Policy'] = [
        "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:",
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://builder.localhost https://*.localhost",
        "connect-src 'self' https://builder.localhost ws://builder.localhost wss://builder.localhost https://*.localhost ws://*.localhost wss://*.localhost",
        "frame-ancestors https://builder.localhost http://builder.localhost https://*.localhost http://*.localhost",
        "img-src 'self' data: blob: https:",
        "font-src 'self' data:",
        "style-src 'self' 'unsafe-inline'"
      ].join('; ')
      
      # Allow cross-origin requests from builder
      headers['Access-Control-Allow-Origin'] = 'https://builder.localhost'
      headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS, HEAD'
      headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization'
      headers['Access-Control-Allow-Credentials'] = 'true'
      
      # Signal DevTools support via header
      headers['Access-Control-Expose-Headers'] = 'DevTools-Enabled'
      headers['DevTools-Enabled'] = 'true'
      
      # Add X-DevTools-Monitor header for easier debugging
      headers['X-DevTools-Monitor'] = 'active'
      
      # Inject DevTools script into HTML responses (including error pages)
      if headers['Content-Type']&.include?('text/html') && response.respond_to?(:body)
        body = response_body_to_string(response)
        
        # Only inject if it's not already there and has a </head> tag
        if body && !body.include?('devtools_monitor.js') && body.include?('</head>')
          devtools_script = <<~HTML
            <!-- DevTools Monitor for AllSpark Builder -->
            <meta name="devtools-enabled" content="true">
            <script src="/assets/devtools_monitor.js" defer></script>
          HTML
          
          # Insert before closing </head> tag
          modified_body = body.sub('</head>', "#{devtools_script}</head>")
          
          # Update response
          headers['Content-Length'] = modified_body.bytesize.to_s
          response = [modified_body]
        end
      end
    end
    
    [status, headers, response]
  end
  
  private
  
  def response_body_to_string(response)
    body = ""
    response.each { |part| body << part.to_s }
    body
  rescue
    nil
  end

  def devtools_enabled?
    # Enable DevTools in development or when DEVTOOLS_ENABLED=true
    Rails.env.development? || ENV['DEVTOOLS_ENABLED'] == 'true'
  end
end

# Configuration is handled in config/application.rb:
# config.middleware.use DevToolsMiddleware