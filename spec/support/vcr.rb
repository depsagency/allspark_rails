# frozen_string_literal: true

# VCR configuration for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock

  # Allow localhost connections for test server
  config.ignore_localhost = true

  # Filter sensitive data
  config.filter_sensitive_data('<GOOGLE_API_KEY>') { ENV['GOOGLE_API_KEY'] }
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<CLAUDE_API_KEY>') { ENV['CLAUDE_API_KEY'] }
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV['GEMINI_API_KEY'] }
  # MCP-specific sensitive data
  config.filter_sensitive_data('<LINEAR_API_KEY>') { ENV['LINEAR_API_KEY'] }
  config.filter_sensitive_data('<GITHUB_TOKEN>') { ENV['GITHUB_TOKEN'] }
  config.filter_sensitive_data('<SLACK_TOKEN>') { ENV['SLACK_TOKEN'] }

  # Configure default cassette options
  config.default_cassette_options = {
    serialize_with: :json,
    preserve_exact_body_bytes: true,
    match_requests_on: [ :method, :uri, :headers, :body ],
    record: :once
  }

  # Ignore requests to common development URLs
  config.ignore_hosts(
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    'selenium',
    'chrome',
    'chromedriver-downloads.storage.googleapis.com'
  )

  # Configure for different record modes based on environment
  if ENV['VCR_RECORD_MODE']
    config.default_cassette_options[:record] = ENV['VCR_RECORD_MODE'].to_sym
  end

  # Allow HTTP connections when VCR is turned off
  config.allow_http_connections_when_no_cassette = false

  # Configure for CI
  if ENV['CI']
    config.default_cassette_options[:record] = :none
  end
end

# RSpec integration
RSpec.configure do |config|
  # Automatically use VCR for specs tagged with :vcr
  config.around(:each, :vcr) do |example|
    name = example.metadata[:full_description]
                  .split(/\s+/, 2)
                  .join('/')
                  .underscore
                  .gsub(/[^\w\/]+/, '_')
                  .gsub(/\/$/, '')

    options = example.metadata.slice(:record, :match_requests_on)
                     .with_indifferent_access

    VCR.use_cassette(name, options) { example.call }
  end

  # Clean up cassettes for specs that might create them dynamically
  config.after(:each) do
    VCR.eject_cassette if VCR.current_cassette
  end
end
