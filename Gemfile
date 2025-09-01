source "https://rubygems.org"

# AllSpark monitoring gem for integration with AllSpark Builder  
gem 'allspark', path: 'vendor/gems/allspark'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.0"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use PostgreSQL as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing frameworks
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"

  # Additional testing and quality tools
  gem "simplecov", require: false
  gem "vcr"
  gem "timecop"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :production do
  # Heroku-specific memory management for Puma
  gem "puma_worker_killer"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Additional testing tools
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  gem "cuprite"
  gem "webmock"
  gem "pundit-matchers"
  gem "rspec-sidekiq"
  gem "rspec-json_expectations"
end

group :development do
  gem "better_errors"
  gem "binding_of_caller"
  gem "ruby-lsp-rails", require: false
  gem "letter_opener_web"
end

# Addons
gem "devise"
gem "enum_help"
gem "inline_svg"
gem "kaminari"
gem "responders"
gem "show_for"
gem "simple_form"
gem "simple-navigation"

# Google Workspace Integration
gem "google-apis-drive_v3"
gem "google-apis-gmail_v1"
gem "google-apis-calendar_v3"
gem "googleauth"
gem "google-cloud-storage"

# Enhanced Authentication & Authorization
gem "pundit"
gem "devise-jwt"
gem "rack-cors"

# UI & Component Library
gem "view_component"
gem "lookbook", group: :development
gem "dry-initializer"

# API & Serialization
gem "jsonapi-serializer"

# File Processing
gem "image_processing", "~> 1.12"

# Background Jobs & Environment
gem "sidekiq"        # Background job processing
gem "redis"          # For Sidekiq and caching
gem "dotenv-rails"   # Environment variables


# Markdown processing
gem "redcarpet"      # For markdown to HTML conversion

# AI Agent Support
gem 'langchainrb', '~> 0.16.0'
gem 'langchainrb_rails', '~> 0.1.12'

# Tool Dependencies
gem 'eqn', '~> 1.6'        # For calculator tool
gem 'safe_ruby', '~> 1.0'  # For Ruby code interpreter
gem 'tiktoken_ruby', '~> 0.0.9'  # For token counting

# Optional tool gems
gem 'google_search_results', '~> 2.2'  # For Google search tool

gem 'news-api', '~> 0.2'              # For news retrieval

# External service integrations
gem 'httparty', '~> 0.21'  # For API calls
gem 'oauth2', '~> 2.0'     # For OAuth authentication

# Analytics and monitoring
gem 'groupdate', '~> 6.4'  # For time-based grouping

# AllSpark monitoring gem for integration with AllSpark Builder
# gem 'allspark', path: '../../vendor/gems/allspark'

# Vector database and embeddings
gem 'neighbor', '~> 0.5'   # PostgreSQL vector similarity search (pgvector support)
gem 'ruby-openai', '~> 7.3'  # For embeddings generation
gem 'anthropic', '~> 0.3.0'  # For Claude API integration
