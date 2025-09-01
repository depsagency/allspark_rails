# Ruby Style Guide

This guide outlines the Ruby and Rails coding conventions used in the AllSpark project.

## General Ruby Style

### Indentation and Whitespace
- Use 2 spaces for indentation (no tabs)
- No trailing whitespace
- End files with a newline
- Use spaces around operators and after commas

```ruby
# Good
sum = 1 + 2
array = [1, 2, 3]

# Bad
sum=1+2
array=[1,2,3]
```

### Line Length
- Keep lines under 80 characters when possible
- Maximum 120 characters for complex lines
- Break long method chains

```ruby
# Good
user.posts
  .published
  .where(category: 'tech')
  .order(created_at: :desc)

# Bad
user.posts.published.where(category: 'tech').order(created_at: :desc).limit(10).includes(:comments)
```

### Naming Conventions
- Use `snake_case` for methods and variables
- Use `CamelCase` for classes and modules
- Use `SCREAMING_SNAKE_CASE` for constants
- Prefix boolean methods with `is_`, `has_`, or `can_`

```ruby
# Good
class UserAccount
  MAX_LOGIN_ATTEMPTS = 5

  def can_login?
    login_attempts < MAX_LOGIN_ATTEMPTS
  end

  private

  def calculate_subscription_fee
    # ...
  end
end
```

### Method Definitions
- Use parentheses for method parameters
- Omit parentheses for DSL-style methods
- Keep methods short (under 10 lines ideally)

```ruby
# Good
def calculate_total(items, tax_rate)
  subtotal = items.sum(&:price)
  subtotal * (1 + tax_rate)
end

# DSL-style (no parens)
before_action :authenticate_user!
validates :email, presence: true
```

## Rails-Specific Conventions

### Models
- Keep models thin, use concerns for shared behavior
- Validate data integrity at the model level
- Use scopes for commonly used queries

```ruby
class User < ApplicationRecord
  # Constants
  ROLES = %w[admin user guest].freeze

  # Associations
  has_many :posts, dependent: :destroy
  belongs_to :organization

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: 'admin') }

  # Callbacks
  before_save :normalize_email

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  private

  def normalize_email
    self.email = email.downcase.strip
  end
end
```

### Controllers
- Keep controllers thin
- Use before_action for common setup
- Respond with appropriate status codes

```ruby
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    @projects = current_user.projects.page(params[:page])
  end

  def create
    @project = current_user.projects.build(project_params)

    if @project.save
      redirect_to @project, notice: 'Project created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
```

### Service Objects
- Use service objects for complex business logic
- Return consistent response objects
- Handle errors gracefully

```ruby
module Projects
  class CreateService
    def initialize(user, params)
      @user = user
      @params = params
    end

    def call
      ActiveRecord::Base.transaction do
        project = create_project
        create_default_settings(project)
        notify_team(project)
        
        ServiceResult.success(project: project)
      end
    rescue StandardError => e
      ServiceResult.error(message: e.message)
    end

    private

    attr_reader :user, :params

    def create_project
      user.projects.create!(params)
    end

    def create_default_settings(project)
      project.create_settings!(default_settings)
    end

    def notify_team(project)
      ProjectMailer.created(project).deliver_later
    end

    def default_settings
      { theme: 'light', notifications: true }
    end
  end
end
```

### Views and Helpers
- Use semantic HTML
- Extract complex logic to helpers or components
- Prefer ViewComponents over partials for reusable UI

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def format_date(date)
    return '-' if date.blank?
    date.strftime('%B %d, %Y')
  end

  def user_avatar(user, size: 'md')
    classes = {
      'sm' => 'w-8 h-8',
      'md' => 'w-12 h-12',
      'lg' => 'w-16 h-16'
    }

    content_tag :div, class: "avatar #{classes[size]}" do
      if user.avatar.attached?
        image_tag user.avatar, class: 'rounded-full'
      else
        content_tag :div, user.initials, class: 'avatar-placeholder'
      end
    end
  end
end
```

## Testing Style

### RSpec Conventions
- Use descriptive test names
- Keep tests focused and isolated
- Use factories instead of fixtures

```ruby
RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns the combined first and last name' do
      expect(user.full_name).to eq('John Doe')
    end

    context 'when last name is missing' do
      let(:user) { build(:user, first_name: 'John', last_name: nil) }

      it 'returns only the first name' do
        expect(user.full_name).to eq('John')
      end
    end
  end
end
```

## Code Organization

### File Structure
```
app/
├── controllers/
│   ├── api/          # API controllers
│   ├── concerns/     # Shared controller concerns
│   └── application_controller.rb
├── models/
│   ├── concerns/     # Shared model concerns
│   └── application_record.rb
├── services/         # Service objects
│   ├── projects/
│   └── users/
├── jobs/            # Background jobs
├── mailers/         # Email classes
└── components/      # ViewComponents
```

### Module and Class Organization
1. Constants
2. Concerns and modules
3. Associations
4. Validations
5. Callbacks
6. Scopes
7. Class methods
8. Instance methods
9. Private methods

## Security Best Practices

### Parameter Filtering
Always use strong parameters:
```ruby
def user_params
  params.require(:user).permit(:name, :email, :role)
end
```

### SQL Injection Prevention
Use parameterized queries:
```ruby
# Good
User.where(email: params[:email])
User.where('created_at > ?', 1.week.ago)

# Bad
User.where("email = '#{params[:email]}'")
```

## Performance Guidelines

### Database Queries
- Use includes/joins to avoid N+1 queries
- Add appropriate database indexes
- Use counter caches for associations

```ruby
# Good - Eager loading
@posts = Post.includes(:user, :comments).published

# Bad - N+1 query
@posts = Post.published
# In view: @posts.each { |post| post.user.name }
```

### Caching
Use Rails caching effectively:
```ruby
class Product < ApplicationRecord
  def expensive_calculation
    Rails.cache.fetch(['product', id, 'calculation'], expires_in: 1.hour) do
      # Expensive operation
    end
  end
end
```

## RuboCop Configuration

We use RuboCop with the following key rules:

```yaml
# .rubocop.yml
AllCops:
  NewCops: enable
  TargetRubyVersion: 3.3

Style/Documentation:
  Enabled: false

Metrics/MethodLength:
  Max: 20

Metrics/ClassLength:
  Max: 200

Style/FrozenStringLiteralComment:
  Enabled: true
```

Run RuboCop:
```bash
bundle exec rubocop
bundle exec rubocop -a  # Auto-fix issues
```