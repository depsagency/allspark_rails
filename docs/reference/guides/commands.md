# Rails Template Command Reference

Quick reference for commonly used commands in this Rails application.

## 🚀 Development Setup

```bash
# Initial setup (one-time)
rake setup:dev              # Complete development setup
rake setup:health           # Check system health
rake setup:create_admin     # Create admin user

# Start development
bin/dev                     # Start all services (recommended)
rails server                # Start Rails only
bundle exec sidekiq         # Start Sidekiq only

# Database
rails db:create             # Create database
rails db:migrate            # Run migrations
rails db:seed               # Seed data
rails db:reset              # Drop, create, migrate, seed
rake setup:reset_db         # Full database reset
```

## 🧪 Testing & Quality

```bash
# Run tests
rails test                  # Run all tests
rails test:system           # Run system tests
rails test path/to/test.rb  # Run specific test

# Code quality
rake quality:all            # Run all quality checks
rake quality:rubocop        # Ruby style check
rake quality:fix            # Auto-fix style issues
rake quality:brakeman       # Security scan
rake quality:bundle_audit   # Check for vulnerable gems

# Coverage
open coverage/index.html    # View test coverage
```

## 🤖 AI/LLM Commands

```bash
# LLM management
rake llm:status             # Check LLM configuration
rake llm:test               # Test all providers
rake llm:clear_cache        # Clear LLM cache
rake llm:help               # Show LLM help

# Test in console
rails c
> Llm::Client.new.generate(prompt: "Hello")
```

## 🔨 Generators

```bash
# UI Components
rails g ui_component button --variants=primary,secondary
rails g ui_component modal --with-stimulus

# Custom generators
rails g api_controller resource_name
rails g service payment_processor
rails g ai_model product --description="Product model"

# Standard Rails generators with DaisyUI
rails g scaffold Product name:string price:decimal
rails g controller Products index show
```

## 🐳 Docker Commands

```bash
# Docker development
docker-compose up -d        # Start all containers
docker-compose down         # Stop all containers
docker-compose logs -f web  # View logs
docker-compose exec web bash # Shell access

# Run commands in container
docker-compose exec web rails console
docker-compose exec web rails db:migrate
docker-compose exec web bundle install
```

## 📦 Dependency Management

```bash
# Ruby gems
bundle install              # Install gems
bundle update               # Update all gems
bundle update gem_name      # Update specific gem
bundle outdated             # Check outdated gems

# JavaScript packages
yarn install                # Install packages
yarn add package_name       # Add new package
yarn upgrade                # Update packages
yarn outdated               # Check outdated packages

# Dependabot management
bin/dependabot-status       # Check status of Dependabot PRs
bin/merge-dependabot        # Merge Dependabot PRs interactively
bin/merge-dependabot --all  # Merge all ready PRs
bin/merge-dependabot --list # List PRs without processing
```

## 🔍 Debugging

```bash
# Rails console
rails console               # Production/dev console
rails console --sandbox     # Safe console (rollback)

# Debugging
rails server --debugger     # Start with debugger
binding.pry                 # Add to code for breakpoint
byebug                      # Alternative debugger

# Logs
tail -f log/development.log # Watch logs
rails log:clear             # Clear logs
```

## 🚀 Deployment

```bash
# Heroku
heroku create app-name      # Create new app
git push heroku main        # Deploy
heroku run rails db:migrate # Run migrations
heroku logs --tail          # View logs
heroku run rails console    # Production console

# Asset compilation
rails assets:precompile     # Compile assets
rails assets:clean          # Clean old assets
```

## 📊 Database

```bash
# Migrations
rails g migration AddFieldToModel field:type
rails db:migrate            # Run pending migrations
rails db:rollback           # Rollback last migration
rails db:migrate:status     # Check migration status

# Database console
rails db                    # Open database console
rails dbconsole             # Alternative

# Backup/Restore (PostgreSQL)
pg_dump -U postgres myapp_dev > backup.sql
psql -U postgres myapp_dev < backup.sql
```

## 🔧 Maintenance

```bash
# Clear caches
rails tmp:clear             # Clear temp files
rails cache:clear           # Clear Rails cache
redis-cli FLUSHALL          # Clear Redis (careful!)

# Application maintenance
rake app:rename[NewName]    # Rename application
rake setup:generate_secrets # Generate new secrets
```

## 🎯 Sidekiq

```bash
# Start Sidekiq
bundle exec sidekiq         # Start worker
bundle exec sidekiq -C config/sidekiq.yml

# Monitor Sidekiq
# Visit: http://localhost:3000/sidekiq

# Clear jobs
rails c
> Sidekiq::Queue.all.map(&:clear)
> Sidekiq::RetrySet.new.clear
```

## 📧 Email Testing

```bash
# Development emails
# Visit: http://localhost:3000/letter_opener

# Test mailer in console
rails c
> TestMailer.test_email.deliver_now
```

## 🎨 UI Development

```bash
# View components
# Visit: http://localhost:3000/lookbook

# Generate component
rails g ui_component card --variants=bordered,compact

# Test components
rspec spec/components/
```

## 🔐 Security

```bash
# Generate secrets
rails secret                # Generate secret key
rails credentials:edit      # Edit credentials

# Security checks
brakeman                    # Security scan
bundle audit                # Check gems
```

## 📝 Useful Rails Console Commands

```ruby
# Reload console
reload!

# Pretty print
pp User.all

# Measure time
time { User.count }

# Find by various attributes
User.find_by(email: "test@example.com")
User.where(role: "admin")

# Update records
User.update_all(confirmed: true)

# Delete records (careful!)
User.where(created_at: 1.week.ago..Time.current).destroy_all

# View routes
Rails.application.routes.url_helpers.root_path
app.users_path

# Make HTTP requests in console
app.get "/users"
app.response.body
```

## 🆘 Troubleshooting

```bash
# Bundle issues
rm Gemfile.lock
bundle install

# Asset issues
rails assets:clobber        # Remove compiled assets
rails assets:precompile

# Database issues
rails db:drop               # Drop database
rails db:create             # Recreate database
rails db:schema:load        # Load schema

# Permission issues
sudo chown -R $USER:$USER .

# Port in use
lsof -i :3000               # Find process
kill -9 PID                 # Kill process
```

## ⚡ Performance

```bash
# Bullet (N+1 queries)
# Check log/bullet.log

# Benchmark
rails runner 'puts Benchmark.measure { 1000.times { User.first } }'

# Profile
# Add rack-mini-profiler to Gemfile
# Visit any page with ?pp=profile-memory
```

## 🔄 Git Workflow

```bash
# Feature branch
git checkout -b feature/name
git add .
git commit -m "Add feature"
git push origin feature/name

# Update from main
git checkout main
git pull origin main
git checkout feature/name
git rebase main
```

## 📱 Mobile Development

```bash
# Test responsive design
rails s -b 0.0.0.0          # Bind to all interfaces
# Access from mobile: http://computer-ip:3000

# Ngrok for external access
ngrok http 3000
```

## 🏃 Quick Scripts

```bash
# One-liner to reset everything
rake setup:reset_db && rails db:seed && rails s

# Full quality check before commit
rake quality:all && rails test

# Quick deploy to Heroku
git push heroku main && heroku run rails db:migrate
```