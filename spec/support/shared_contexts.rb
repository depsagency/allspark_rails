# frozen_string_literal: true

# Shared contexts for common test scenarios

RSpec.shared_context 'authenticated user' do
  let(:current_user) { create(:user) }

  before do
    sign_in current_user
  end
end

RSpec.shared_context 'authenticated admin' do
  let(:current_admin) { create(:user, :admin) }

  before do
    sign_in current_admin
  end
end

RSpec.shared_context 'unauthenticated user' do
  before do
    sign_out :user if respond_to?(:sign_out)
  end
end

RSpec.shared_context 'with notifications' do
  let!(:read_notification) do
    create(:notification, user: current_user, read_at: 1.hour.ago)
  end

  let!(:unread_notification) do
    create(:notification, user: current_user, read_at: nil)
  end

  let!(:other_user_notification) do
    create(:notification, user: create(:user))
  end
end

RSpec.shared_context 'with stubbed time' do |time = nil|
  let(:frozen_time) { time || Time.zone.parse('2024-01-01 12:00:00') }

  around do |example|
    Timecop.freeze(frozen_time) do
      example.run
    end
  end
end

RSpec.shared_context 'with sidekiq jobs' do
  before do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  after do
    Sidekiq::Worker.clear_all
  end
end

RSpec.shared_context 'with real sidekiq' do
  before do
    Sidekiq::Testing.inline!
  end

  after do
    Sidekiq::Testing.fake!
  end
end

RSpec.shared_context 'with mocked external apis' do
  before do
    WebMock.disable_net_connect!(allow_localhost: true)

    # Mock common external API endpoints
    stub_request(:any, /googleapis\.com/).to_return(
      status: 200,
      body: { success: true }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    stub_request(:any, /openai\.com/).to_return(
      status: 200,
      body: { choices: [ { message: { content: 'Mocked response' } } ] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end

RSpec.shared_context 'with actioncable test adapter' do
  before do
    ActionCable.server.config.cable = { 'adapter' => 'test' }
  end
end

RSpec.shared_context 'with live updates enabled' do
  before do
    allow(Rails.application.config).to receive(:live_updates_enabled).and_return(true)
  end
end

RSpec.shared_context 'with component preview' do
  let(:component_class) { described_class }
  let(:component_preview_class) do
    "#{component_class.name}Preview".constantize
  rescue NameError
    nil
  end

  before do
    skip 'No preview class found' unless component_preview_class
  end
end

RSpec.shared_context 'with cache enabled' do
  before do
    allow(Rails.cache).to receive(:fetch).and_call_original
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:write).and_call_original
  end
end

RSpec.shared_context 'with feature flags' do |flags = {}|
  before do
    flags.each do |flag, value|
      allow(Rails.application.config.features).to receive(flag).and_return(value)
    end
  end
end

RSpec.shared_context 'with google workspace mocked' do
  let(:mock_drive_service) { instance_double(GoogleDriveService) }
  let(:mock_gmail_service) { instance_double(GmailService) }
  let(:mock_calendar_service) { instance_double(CalendarService) }

  before do
    allow(GoogleDriveService).to receive(:new).and_return(mock_drive_service)
    allow(GmailService).to receive(:new).and_return(mock_gmail_service)
    allow(CalendarService).to receive(:new).and_return(mock_calendar_service)

    # Stub common methods
    allow(mock_drive_service).to receive(:test_connection).and_return(true)
    allow(mock_gmail_service).to receive(:test_connection).and_return(true)
    allow(mock_calendar_service).to receive(:test_connection).and_return(true)
  end
end

RSpec.shared_context 'with database cleaner' do
  before do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  after do
    DatabaseCleaner.clean
  end
end

RSpec.shared_context 'with test uploads' do
  let(:test_image) do
    fixture_file_upload(
      Rails.root.join('spec', 'fixtures', 'test_image.jpg'),
      'image/jpeg'
    )
  end

  let(:test_document) do
    fixture_file_upload(
      Rails.root.join('spec', 'fixtures', 'test_document.pdf'),
      'application/pdf'
    )
  end

  after do
    # Clean up uploaded files in test
    uploaded_files = ActiveStorage::Blob.all
    uploaded_files.each(&:purge) if uploaded_files.any?
  end
end
