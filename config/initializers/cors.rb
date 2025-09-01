# frozen_string_literal: true

# Configure CORS to allow iframe embedding with credentials
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In development, allow requests from builder.localhost
    if Rails.env.development?
      origins 'http://builder.localhost', 'http://builder.localhost:3000', 
              'http://localhost:3000', 'http://localhost:3001', 'http://localhost:3100',
              'https://builder.localhost', 'https://builder.localhost:3000',
              'https://target.localhost',
              /\Ahttp:\/\/.*\.localhost(:\d+)?\z/,
              /\Ahttps:\/\/.*\.localhost(:\d+)?\z/
      
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        credentials: true,  # This is crucial for cookies
        expose: ['X-CSRF-Token', 'Location', 'X-DevTools-Enabled', 'X-DevTools-Version']
    end
  end
end