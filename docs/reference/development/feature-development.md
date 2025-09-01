# Feature Development Workflow

This guide outlines the standard workflow for developing new features in this Rails application.

## Overview

Our feature development follows a structured process:
1. **Planning** - Define requirements and approach
2. **Setup** - Create branch and initial structure  
3. **Implementation** - Build the feature incrementally
4. **Testing** - Write comprehensive tests
5. **Review** - Code review and refinement
6. **Deployment** - Merge and deploy

## Step-by-Step Workflow

### 1. Planning Phase

#### Understand Requirements
```bash
# Review the PRD or task description
# Check /docs/app-projects/generated/{id}/ for generated requirements

# Questions to answer:
- What problem does this solve?
- Who are the users?
- What are the acceptance criteria?
- Are there design mockups?
```

#### Technical Planning
```markdown
## Feature: User Profile Settings

### Models Needed
- [ ] UserPreference model
- [ ] Update User associations

### Controllers
- [ ] Settings::ProfileController

### Views/Components  
- [ ] UI::Forms::ProfileFormComponent
- [ ] Settings layout

### Services
- [ ] ProfileUpdateService

### Background Jobs
- [ ] ProfileImageProcessorJob

### Tests
- [ ] Model specs
- [ ] Request specs
- [ ] System specs
```

### 2. Setup Phase

#### Create Feature Branch
```bash
# Always branch from main
git checkout main
git pull origin main
git checkout -b feature/user-profile-settings

# For bug fixes
git checkout -b fix/profile-image-upload
```

#### Set Up File Structure
```bash
# Create directories if needed
mkdir -p app/controllers/settings
mkdir -p app/services/users
mkdir -p app/components/ui/forms
mkdir -p spec/services/users
```

### 3. Implementation Phase

#### Follow TDD Approach

##### Step 1: Write Failing Test
```ruby
# spec/models/user_preference_spec.rb
require 'rails_helper'

RSpec.describe UserPreference, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:theme) }
  end
end
```

##### Step 2: Implement Minimum Code
```ruby
# app/models/user_preference.rb
class UserPreference < ApplicationRecord
  belongs_to :user
  
  validates :theme, presence: true
end
```

##### Step 3: Make Test Pass
```bash
rails generate migration CreateUserPreferences user:references theme:string
rails db:migrate
rails test spec/models/user_preference_spec.rb
```

#### Database Changes

##### Create Migration
```bash
# Generate migration
rails generate migration AddPreferencesToUsers

# Or for new table
rails generate migration CreateUserPreferences
```

##### Write Migration
```ruby
class CreateUserPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :user_preferences, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :theme, default: 'light'
      t.boolean :email_notifications, default: true
      t.jsonb :settings, default: {}
      
      t.timestamps
    end
    
    add_index :user_preferences, :user_id, unique: true
  end
end
```

#### Model Implementation

```ruby
# app/models/user_preference.rb
class UserPreference < ApplicationRecord
  belongs_to :user
  
  THEMES = %w[light dark auto].freeze
  
  validates :theme, inclusion: { in: THEMES }
  
  store_accessor :settings, :language, :timezone
  
  after_initialize :set_defaults
  
  private
  
  def set_defaults
    self.theme ||= 'light'
    self.settings ||= {}
  end
end

# Update User model
class User < ApplicationRecord
  has_one :user_preference, dependent: :destroy
  delegate :theme, :email_notifications, to: :user_preference, allow_nil: true
  
  after_create :create_default_preference
  
  private
  
  def create_default_preference
    create_user_preference unless user_preference
  end
end
```

#### Controller Implementation

```ruby
# app/controllers/settings/profiles_controller.rb
module Settings
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user
    
    def show
      @preference = current_user.user_preference
    end
    
    def edit
      @preference = current_user.user_preference
    end
    
    def update
      @preference = current_user.user_preference
      
      if ProfileUpdateService.new(@user, profile_params).call
        redirect_to settings_profile_path, notice: t('.success')
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    private
    
    def set_user
      @user = current_user
    end
    
    def profile_params
      params.require(:user).permit(
        :name, :email, :avatar,
        user_preference_attributes: [:theme, :email_notifications]
      )
    end
  end
end
```

#### Service Object Pattern

```ruby
# app/services/users/profile_update_service.rb
module Users
  class ProfileUpdateService
    attr_reader :user, :params
    
    def initialize(user, params)
      @user = user
      @params = params
    end
    
    def call
      ActiveRecord::Base.transaction do
        update_user!
        update_preferences!
        process_avatar! if avatar_changed?
        notify_user!
        
        true
      end
    rescue ActiveRecord::RecordInvalid
      false
    end
    
    private
    
    def update_user!
      user.update!(user_params)
    end
    
    def update_preferences!
      preference_params = params[:user_preference_attributes]
      return unless preference_params
      
      user.user_preference.update!(preference_params)
    end
    
    def process_avatar!
      ProfileImageProcessorJob.perform_later(user)
    end
    
    def avatar_changed?
      params[:avatar].present?
    end
    
    def notify_user!
      UserMailer.profile_updated(user).deliver_later
    end
    
    def user_params
      params.except(:user_preference_attributes)
    end
  end
end
```

#### View Component Implementation

```ruby
# app/components/ui/forms/profile_form_component.rb
module UI
  module Forms
    class ProfileFormComponent < BaseComponent
      def initialize(user:, url:, **options)
        @user = user
        @url = url
        super(**options)
      end
      
      private
      
      attr_reader :user, :url
      
      def preference
        @preference ||= user.user_preference
      end
    end
  end
end
```

```erb
<!-- app/components/ui/forms/profile_form_component.html.erb -->
<%= simple_form_for user, url: url, html: { class: "space-y-6" } do |f| %>
  <div class="card bg-base-100">
    <div class="card-body">
      <h2 class="card-title">Profile Information</h2>
      
      <%= f.input :name,
                  input_html: { class: "input input-bordered" },
                  wrapper_html: { class: "form-control" } %>
                  
      <%= f.input :email,
                  input_html: { class: "input input-bordered" },
                  wrapper_html: { class: "form-control" } %>
                  
      <div class="form-control">
        <%= f.label :avatar, class: "label" %>
        <%= f.file_field :avatar, class: "file-input file-input-bordered" %>
      </div>
    </div>
  </div>
  
  <div class="card bg-base-100">
    <div class="card-body">
      <h2 class="card-title">Preferences</h2>
      
      <%= f.simple_fields_for :user_preference do |pref| %>
        <%= pref.input :theme,
                      collection: UserPreference::THEMES,
                      input_html: { class: "select select-bordered" },
                      wrapper_html: { class: "form-control" } %>
                      
        <div class="form-control">
          <label class="label cursor-pointer">
            <span class="label-text">Email notifications</span>
            <%= pref.check_box :email_notifications, class: "toggle toggle-primary" %>
          </label>
        </div>
      <% end %>
    </div>
  </div>
  
  <div class="flex gap-4">
    <%= f.button :submit, "Save Changes", class: "btn btn-primary" %>
    <%= link_to "Cancel", settings_profile_path, class: "btn btn-ghost" %>
  </div>
<% end %>
```

### 4. Testing Phase

#### Model Tests
```ruby
# spec/models/user_preference_spec.rb
require 'rails_helper'

RSpec.describe UserPreference, type: :model do
  let(:user) { create(:user) }
  let(:preference) { create(:user_preference, user: user) }
  
  describe 'validations' do
    it { should validate_inclusion_of(:theme).in_array(UserPreference::THEMES) }
  end
  
  describe 'associations' do
    it { should belong_to(:user) }
  end
  
  describe 'defaults' do
    it 'sets default theme' do
      pref = UserPreference.new
      expect(pref.theme).to eq('light')
    end
  end
end
```

#### Service Tests
```ruby
# spec/services/users/profile_update_service_spec.rb
require 'rails_helper'

RSpec.describe Users::ProfileUpdateService do
  let(:user) { create(:user) }
  let(:params) do
    {
      name: 'New Name',
      user_preference_attributes: {
        theme: 'dark'
      }
    }
  end
  let(:service) { described_class.new(user, params) }
  
  describe '#call' do
    it 'updates user attributes' do
      expect { service.call }
        .to change { user.reload.name }
        .to('New Name')
    end
    
    it 'updates preferences' do
      expect { service.call }
        .to change { user.user_preference.reload.theme }
        .to('dark')
    end
    
    it 'enqueues notification email' do
      expect { service.call }
        .to have_enqueued_mail(UserMailer, :profile_updated)
    end
  end
end
```

#### System Tests
```ruby
# spec/system/settings/profile_spec.rb
require 'rails_helper'

RSpec.describe 'Profile Settings', type: :system do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end
  
  scenario 'User updates profile' do
    visit settings_profile_path
    
    fill_in 'Name', with: 'New Name'
    select 'Dark', from: 'Theme'
    uncheck 'Email notifications'
    
    click_button 'Save Changes'
    
    expect(page).to have_content('Profile updated successfully')
    expect(user.reload.name).to eq('New Name')
    expect(user.theme).to eq('dark')
    expect(user.email_notifications).to be_falsey
  end
end
```

### 5. Code Quality Phase

#### Run Quality Checks
```bash
# Run all checks
rake quality:all

# Fix style issues
rake quality:fix

# Security scan
rake quality:brakeman
```

#### Add Documentation
```ruby
# Document complex methods
# @param user [User] The user to update
# @param params [Hash] Update parameters
# @return [Boolean] Success status
def call
  # ...
end
```

### 6. Review Phase

#### Self Review Checklist
- [ ] All tests passing
- [ ] No console.log or debugger statements
- [ ] No commented out code
- [ ] Proper error handling
- [ ] UI works on mobile
- [ ] Accessibility checked
- [ ] Performance acceptable
- [ ] Security considerations addressed

#### Create Pull Request
```bash
# Push branch
git add .
git commit -m "Add user profile settings feature"
git push origin feature/user-profile-settings

# Create PR with template
```

#### PR Description Template
```markdown
## Summary
Brief description of what this PR does

## Type of Change
- [ ] Bug fix
- [x] New feature
- [ ] Breaking change
- [ ] Documentation update

## How Has This Been Tested?
- [x] Unit tests
- [x] Integration tests
- [x] Manual testing

## Checklist
- [x] Code follows style guidelines
- [x] Self-review completed
- [x] Comments added for complex code
- [x] Documentation updated
- [x] No new warnings
- [x] Tests added and passing
- [x] Dependent changes merged

## Screenshots
[If applicable]
```

### 7. Deployment Phase

#### After Merge
```bash
# Update local main
git checkout main
git pull origin main

# Delete feature branch
git branch -d feature/user-profile-settings
git push origin --delete feature/user-profile-settings
```

#### Deploy to Staging
```bash
# Automatic deployment or
git push staging main
heroku run rails db:migrate -a myapp-staging
```

#### Production Deployment
```bash
# After staging verification
git push production main
heroku run rails db:migrate -a myapp-production

# Monitor for issues
heroku logs --tail -a myapp-production
```

## Best Practices

### 1. Incremental Development
- Make small, focused commits
- Each commit should pass tests
- Deploy frequently

### 2. Testing Strategy
- Write tests first (TDD)
- Test edge cases
- Mock external services
- Keep tests fast

### 3. Code Organization
- Follow single responsibility
- Extract complex logic to services
- Use concerns for shared behavior
- Keep controllers thin

### 4. UI Development
- Use existing components
- Follow design system
- Test on multiple screen sizes
- Consider accessibility

### 5. Performance
- Use eager loading
- Add database indexes
- Cache expensive operations
- Profile before optimizing

### 6. Security
- Validate all inputs
- Use strong parameters
- Check authorization
- Audit dependencies

## Common Patterns

### Form Objects
```ruby
class ProfileForm
  include ActiveModel::Model
  
  attr_accessor :name, :email, :theme
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  def save
    return false unless valid?
    
    user.update!(attributes)
  end
end
```

### Query Objects
```ruby
class ActiveUsersQuery
  def initialize(relation = User.all)
    @relation = relation
  end
  
  def call
    @relation
      .joins(:user_preference)
      .where(active: true)
      .where('last_sign_in_at > ?', 30.days.ago)
  end
end
```

### Presenter Pattern
```ruby
class UserPresenter < SimpleDelegator
  def display_name
    name.presence || email.split('@').first
  end
  
  def member_since
    created_at.strftime('%B %Y')
  end
end
```

## Troubleshooting

### Common Issues

1. **Failing Tests**
   - Check test database is migrated
   - Clear test cache
   - Check for timing issues

2. **Migration Errors**
   - Rollback and try again
   - Check for data dependencies
   - Use reversible migrations

3. **Performance Problems**
   - Check N+1 queries with Bullet
   - Add missing indexes
   - Use query analysis

4. **UI Issues**
   - Clear asset cache
   - Check browser console
   - Test in different browsers