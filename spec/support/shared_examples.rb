# frozen_string_literal: true

# Shared examples for common test scenarios

RSpec.shared_examples 'requires authentication' do
  context 'when user is not authenticated' do
    before do
      sign_out :user if respond_to?(:sign_out)
    end

    it 'redirects to login page' do
      subject
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

RSpec.shared_examples 'requires admin access' do
  include_examples 'requires authentication'

  context 'when user is authenticated but not admin' do
    let(:regular_user) { create(:user) }

    before do
      sign_in regular_user
    end

    it 'denies access' do
      subject
      expect(response).to have_http_status(:forbidden)
    end
  end
end

RSpec.shared_examples 'a pundit policy' do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:record) { create(described_class.name.demodulize.gsub('Policy', '').underscore.to_sym) }

  describe '#show?' do
    it 'allows admin access' do
      expect(described_class.new(admin, record).show?).to be true
    end
  end

  describe '#create?' do
    it 'allows admin access' do
      expect(described_class.new(admin, record).create?).to be true
    end
  end

  describe '#update?' do
    it 'allows admin access' do
      expect(described_class.new(admin, record).update?).to be true
    end
  end

  describe '#destroy?' do
    it 'allows admin access' do
      expect(described_class.new(admin, record).destroy?).to be true
    end
  end
end

RSpec.shared_examples 'a model with uuid primary key' do
  it 'uses UUID as primary key' do
    expect(described_class.new.id).to be_nil
    record = create(described_class.name.underscore.to_sym)
    expect(record.id).to be_present
    expect(record.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
  end
end

RSpec.shared_examples 'a model with timestamps' do
  it 'has created_at and updated_at timestamps' do
    record = create(described_class.name.underscore.to_sym)
    expect(record.created_at).to be_present
    expect(record.updated_at).to be_present
  end

  it 'updates updated_at when record changes' do
    record = create(described_class.name.underscore.to_sym)
    original_updated_at = record.updated_at

    Timecop.travel(1.minute.from_now) do
      record.touch
      expect(record.updated_at).to be > original_updated_at
    end
  end
end

RSpec.shared_examples 'a live updates model' do
  it 'includes LiveUpdates concern' do
    expect(described_class.ancestors).to include(LiveUpdates)
  end

  it 'broadcasts updates when created' do
    expect(LiveUpdatesBroadcaster).to receive(:broadcast_resource_created)
    create(described_class.name.underscore.to_sym)
  end

  it 'broadcasts updates when changed' do
    record = create(described_class.name.underscore.to_sym)
    expect(LiveUpdatesBroadcaster).to receive(:broadcast_resource_update)
    record.touch
  end

  it 'broadcasts deletion when destroyed' do
    record = create(described_class.name.underscore.to_sym)
    expect(LiveUpdatesBroadcaster).to receive(:broadcast_resource_deleted)
    record.destroy
  end
end

RSpec.shared_examples 'a component' do
  it 'inherits from BaseComponent' do
    expect(described_class.ancestors).to include(BaseComponent)
  end

  it 'can be rendered' do
    component = described_class.new(**component_kwargs)
    expect { render_inline(component) }.not_to raise_error
  end

  it 'produces valid HTML' do
    component = described_class.new(**component_kwargs)
    html = render_inline(component).to_html
    expect(html).to be_present
    expect(html).not_to include('MISSING')
  end
end

RSpec.shared_examples 'a form component' do
  include_examples 'a component'

  it 'accepts name parameter' do
    expect { described_class.new(name: 'test', **component_kwargs) }.not_to raise_error
  end

  it 'generates proper form attributes' do
    component = described_class.new(name: 'test', **component_kwargs)
    html = render_inline(component).to_html
    expect(html).to include('name="test"')
  end
end

RSpec.shared_examples 'a service object' do
  it 'responds to call method' do
    expect(described_class.new).to respond_to(:call)
  end

  it 'includes GoogleWorkspaceIntegration if it uses Google APIs' do
    if described_class.name.include?('Google')
      expect(described_class.ancestors).to include(GoogleWorkspaceIntegration)
    end
  end
end

RSpec.shared_examples 'a background job' do
  it 'inherits from ApplicationJob' do
    expect(described_class.ancestors).to include(ApplicationJob)
  end

  it 'can be enqueued' do
    expect { described_class.perform_later }.not_to raise_error
  end

  it 'has a queue name' do
    expect(described_class.queue_name).to be_present
  end
end

RSpec.shared_examples 'a google workspace job' do
  include_examples 'a background job'

  it 'inherits from GoogleWorkspaceJob' do
    expect(described_class.ancestors).to include(GoogleWorkspaceJob)
  end
end

RSpec.shared_examples 'an actioncable channel' do
  it 'inherits from ApplicationCable::Channel' do
    expect(described_class.ancestors).to include(ApplicationCable::Channel)
  end

  it 'responds to subscribed method' do
    expect(described_class.new(nil, nil)).to respond_to(:subscribed)
  end

  it 'responds to unsubscribed method' do
    expect(described_class.new(nil, nil)).to respond_to(:unsubscribed)
  end
end

RSpec.shared_examples 'a json api response' do |status = :ok|
  it "returns #{status} status" do
    subject
    expect(response).to have_http_status(status)
  end

  it 'returns JSON content type' do
    subject
    expect(response.content_type).to include('application/json')
  end

  it 'returns valid JSON' do
    subject
    expect { JSON.parse(response.body) }.not_to raise_error
  end
end

RSpec.shared_examples 'a paginated response' do
  include_examples 'a json api response'

  it 'includes pagination metadata' do
    subject
    json = JSON.parse(response.body)
    expect(json).to have_key('pagination')
    expect(json['pagination']).to include('current_page', 'total_pages', 'total_count')
  end
end

RSpec.shared_examples 'validates presence of' do |*attributes|
  attributes.each do |attribute|
    it "validates presence of #{attribute}" do
      should validate_presence_of(attribute)
    end
  end
end

RSpec.shared_examples 'validates uniqueness of' do |*attributes|
  attributes.each do |attribute|
    it "validates uniqueness of #{attribute}" do
      should validate_uniqueness_of(attribute)
    end
  end
end

RSpec.shared_examples 'belongs to' do |*associations|
  associations.each do |association|
    it "belongs to #{association}" do
      should belong_to(association)
    end
  end
end

RSpec.shared_examples 'has many' do |*associations|
  associations.each do |association|
    it "has many #{association}" do
      should have_many(association)
    end
  end
end

RSpec.shared_examples 'has one' do |*associations|
  associations.each do |association|
    it "has one #{association}" do
      should have_one(association)
    end
  end
end
