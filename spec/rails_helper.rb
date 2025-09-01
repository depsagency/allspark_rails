# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Testing gems
require 'shoulda/matchers'
require 'pundit/matchers'
require 'capybara/rspec'
require 'webmock/rspec'
require 'database_cleaner/active_record'
require 'timecop'
require 'vcr'
require 'rspec/json_expectations'

# SimpleCov for code coverage
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Components', 'app/components'
  add_group 'Channels', 'app/channels'
  add_group 'Policies', 'app/policies'

  minimum_coverage 80
end

# Sidekiq testing
require 'sidekiq/testing'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # Use FactoryBot instead of fixtures
  config.use_transactional_fixtures = false

  # Infer spec types from file locations
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  config.filter_gems_from_backtrace("gem name")

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Include Pundit matchers
  config.include Pundit::Matchers

  # Include custom helpers
  config.include RequestHelpers, type: :request
  config.include ControllerHelpers, type: :controller
  config.include SystemHelpers, type: :system
  config.include ChannelHelpers, type: :channel

  # Database Cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Configure Sidekiq for testing
  config.before(:each) do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  config.after(:each) do
    Sidekiq::Worker.clear_all
  end

  # Configure system tests
  config.before(:each, type: :system) do
    driven_by :cuprite, using: :chrome, screen_size: [ 1400, 1400 ]
  end

  # ActionCable testing configuration
  config.before(:each, type: :channel) do
    ActionCable.server.config.cable = { "adapter" => "test" }
  end

  # Time travel helpers
  config.after(:each) do
    Timecop.return
  end

  # WebMock configuration
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Shared contexts and examples
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.run_all_when_everything_filtered = true

  # Performance profiling (uncomment to enable)
  # config.profile_examples = 10

  # Randomize spec order
  config.order = :random
  Kernel.srand config.seed
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
