# Middleware to enhance Rails error pages with DevTools reporting
# This injects a script into error pages that reports the error details
# back to the parent window (DevTools) via postMessage

require 'net/http'
require 'json'

class ErrorPageEnhancer
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    Rails.logger.debug "ErrorPageEnhancer: Status #{status}, Headers: #{headers['Content-Type']}"
    
    # Only enhance error pages in development and with valid API key
    if status >= 400 && should_enhance?(env, headers) && valid_api_key?(env)
      exception = env['action_dispatch.exception']
      request = ActionDispatch::Request.new(env)
      
      Rails.logger.debug "ErrorPageEnhancer: Processing error page for #{request.host}#{request.path}"
      Rails.logger.debug "ErrorPageEnhancer: Exception: #{exception.inspect}"
      Rails.logger.debug "ErrorPageEnhancer: Exception class: #{exception&.class&.name}"
      
      # Get response body
      body = response_body_to_string(response)
      
      if body && body.include?('</body>')
        Rails.logger.debug "ErrorPageEnhancer: Enhancing HTML error page"
        enhanced_response = enhance_error_page(response, exception, request, status)
        if enhanced_response
          Rails.logger.debug "ErrorPageEnhancer: Successfully enhanced error page"
          headers['Content-Type'] = 'text/html; charset=utf-8'
          headers['Content-Length'] = enhanced_response.bytesize.to_s
          response = [enhanced_response]
        else
          Rails.logger.debug "ErrorPageEnhancer: Failed to enhance error page"
        end
      else
        Rails.logger.debug "ErrorPageEnhancer: Not an HTML page or no body tag found"
      end
    else
      Rails.logger.debug "ErrorPageEnhancer: Skipping (status: #{status}, should_enhance: #{should_enhance?(env, headers)})"
    end
    
    [status, headers, response]
  rescue => e
    Rails.logger.error "ErrorPageEnhancer failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Return original response if enhancement fails
    [status, headers, response]
  end

  private

  def valid_api_key?(env)
    request = ActionDispatch::Request.new(env)
    provided_key = request.params['devtools_api_key']
    build_session_id = request.params['build_session_id']
    
    return false unless provided_key.present? && build_session_id.present?
    
    # Validate against the AllSpark Builder application
    begin
      uri = URI('http://builder-web:3000/api/validate_monitoring_key')
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 2
      
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body = {
        api_key: provided_key,
        build_session_id: build_session_id
      }.to_json
      
      response = http.request(req)
      return response.code == '200'
    rescue => e
      Rails.logger.debug "API key validation failed: #{e.message}"
      # Fallback: accept any key in development
      return Rails.env.development? && provided_key.present?
    end
  end

  def should_enhance?(env, headers)
    # Only enhance in development
    return false unless Rails.env.development?
    
    # For error pages, the content type might not be set yet, so we check if:
    # 1. It's likely an HTML response (has Accept header for HTML)
    # 2. Or the content type is already HTML
    request = ActionDispatch::Request.new(env)
    accept_header = request.headers['Accept'] || ''
    content_type = headers['Content-Type'] || ''
    
    # Accept if it's HTML content type or if browser is accepting HTML
    return true if content_type.include?('text/html')
    return true if accept_header.include?('text/html')
    
    # Also accept if no content type is set (might be error page that hasn't set it yet)
    return true if content_type.empty? && accept_header.include?('text/html')
    
    false
  end

  def enhance_error_page(response, exception, request, status)
    body = response_body_to_string(response)
    return nil unless body && body.include?('</body>')
    
    # Build error data
    error_data = build_error_data(exception, request, status, body)
    
    # Create the error reporting script
    error_script = <<~HTML
      <!-- DevTools Error Reporter -->
      <script>
        (function() {
          try {
            console.log('🚨 ErrorPageEnhancer: Starting Rails error reporting script');
            console.log('🚨 Window parent check:', window.parent !== window);
            console.log('🚨 Current URL:', window.location.href);
          
          // Report error to parent window (DevTools)
          const errorData = #{error_data.to_json};
          
          // Add some additional context
          errorData.pageTitle = document.title;
          errorData.timestamp = new Date().toISOString();
          
          // Try to extract the formatted error message from the page
          try {
            const headerElement = document.querySelector('header h1');
            if (headerElement) {
              errorData.formattedTitle = headerElement.textContent.trim();
            }
            
            // Get the exception message
            const exceptionElement = document.querySelector('#container h2');
            if (exceptionElement) {
              errorData.formattedMessage = exceptionElement.textContent.trim();
            }
            
            // Try to get source extract if available
            const sourceElement = document.querySelector('.source-extract');
            if (sourceElement) {
              const lineNumbers = Array.from(sourceElement.querySelectorAll('.line-number')).map(el => el.textContent);
              const code = sourceElement.querySelector('code')?.textContent;
              if (code) {
                errorData.sourceExtract = {
                  code: code,
                  lineNumbers: lineNumbers
                };
              }
            }
          } catch (e) {
            console.debug('Could not extract additional error details:', e);
          }
          
          // Send to parent if we're in an iframe
          if (window.parent !== window) {
            console.log('🚨 In iframe context - preparing to send Rails error to DevTools');
            console.log('🚨 Error data to send:', errorData);
            
            // Function to send the error with retries
            const sendRailsError = () => {
              try {
                window.parent.postMessage({
                  type: 'rails-error',
                  source: 'error-page-enhancer',  
                  data: errorData
                }, '*');
                console.log('🚨 Rails error postMessage sent successfully');
              } catch (e) {
                console.error('🚨 Failed to send Rails error postMessage:', e);
              }
            };
            
            // Send immediately
            sendRailsError();
            
            // Also send once after a short delay in case DevTools isn't ready
            setTimeout(sendRailsError, 200);
            
          } else {
            console.log('🚨 Not in iframe, Rails error data available at window.__railsErrorData');
          }
          
          // Also make the error data available globally for debugging
          window.__railsErrorData = errorData;
          
          console.log('🚨 ErrorPageEnhancer: Script completed successfully');
          } catch (error) {
            console.error('🚨 ErrorPageEnhancer: Script failed:', error);
            console.error('🚨 ErrorPageEnhancer: Stack:', error.stack);
          }
        })();
      </script>
    HTML
    
    # Insert before closing body tag
    body.sub('</body>', "#{error_script}</body>")
  end

  def build_error_data(exception, request, status, html_body = nil)
    # Handle cases where there's no exception (like 404s) or extract from HTML
    if exception.nil?
      # Try to extract error details from the HTML body if available
      if html_body && status >= 500
        extracted = extract_error_from_html(html_body)
        if extracted[:error_class] && extracted[:message]
          data = {
            status: status,
            error_class: extracted[:error_class],
            message: extracted[:message],
            path: request.path,
            method: request.request_method,
            params: filter_params(request.params),
            url: request.url,
            referrer: request.referrer,
            backtrace: extracted[:backtrace]
          }
        else
          data = {
            status: status,
            error_class: "HTTP#{status}Error",
            message: "HTTP #{status} Error",
            path: request.path,
            method: request.request_method,
            params: filter_params(request.params),
            url: request.url,
            referrer: request.referrer
          }
        end
      else
        data = {
          status: status,
          error_class: status == 404 ? 'RoutingError' : "HTTP#{status}Error",
          message: status == 404 ? "No route matches [#{request.request_method}] \"#{request.path}\"" : "HTTP #{status} Error",
          path: request.path,
          method: request.request_method,
          params: filter_params(request.params),
          url: request.url,
          referrer: request.referrer
        }
      end
    else
      data = {
        status: status,
        error_class: exception.class.name,
        message: exception.message || 'An error occurred',
        path: request.path,
        method: request.request_method,
        params: filter_params(request.params),
        url: request.url,
        referrer: request.referrer
      }
      
      # Add backtrace if available (limit to first 10 lines for performance)
      if exception.backtrace
        data[:backtrace] = exception.backtrace.first(10)
        
        # Extract the main error location
        if exception.backtrace.first
          file_line_match = exception.backtrace.first.match(/^(.+):(\d+):in `(.+)'$/)
          if file_line_match
            data[:error_location] = {
              file: file_line_match[1],
              line: file_line_match[2].to_i,
              method: file_line_match[3]
            }
          end
        end
      end
      
      # Add cause if there's a chained exception
      if exception.cause
        data[:cause] = {
          class: exception.cause.class.name,
          message: exception.cause.message,
          backtrace: exception.cause.backtrace&.first(5)
        }
      end
    end
    
    data
  end

  def filter_params(params)
    # Filter sensitive parameters
    filtered = params.dup
    Rails.application.config.filter_parameters.each do |param|
      if param.is_a?(Regexp)
        filtered.each_key do |key|
          filtered[key] = '[FILTERED]' if key.to_s =~ param
        end
      else
        filtered[param.to_s] = '[FILTERED]' if filtered.key?(param.to_s)
      end
    end
    filtered
  rescue
    {}
  end

  def response_body_to_string(response)
    body = ""
    response.each { |part| body << part.to_s }
    body
  rescue
    nil
  end

  def extract_error_from_html(html_body)
    error_info = { error_class: nil, message: nil, backtrace: [] }
    
    # Extract error class - look for patterns like "NameError" in the HTML
    if match = html_body.match(/<div class="exception-name">\s*(\w+Error)\s*<\/div>/) ||
              html_body.match(/>\s*(\w+Error)\s*</) ||
              html_body.match(/(\w+Error)/)
      error_info[:error_class] = match[1]
    end
    
    # Extract error message - look for the message div
    if match = html_body.match(/<div class="message">(.*?)<\/div>/m)
      error_info[:message] = match[1].strip.gsub(/<[^>]*>/, '')
    end
    
    # Try to extract backtrace from the HTML
    if html_body.include?('Application Trace') || html_body.include?('Framework Trace')
      # Extract lines from backtrace tables
      backtrace_lines = html_body.scan(/<td class="code"><pre>([^<]+)<\/pre><\/td>/).flatten
      error_info[:backtrace] = backtrace_lines.map(&:strip).reject(&:empty?).first(10)
    end
    
    error_info
  rescue => e
    Rails.logger.debug "Failed to extract error from HTML: #{e.message}"
    { error_class: nil, message: nil, backtrace: [] }
  end
end