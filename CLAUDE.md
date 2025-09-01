# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**CRITICAL: This application runs in a Docker development environment. All commands must be executed inside the web or sidekiq container using `docker-compose exec`.**

**IMPORTANT: Assets are automatically precompiled on container startup if they don't exist. You should not need to run `rails assets:precompile` manually in most cases.**

## Project Overview

This is a Rails 8.0 starter template with modern tooling and best practices built in.

**Key Technologies:**
- Rails 8.0 with esbuild
- PostgreSQL with UUID primary keys
- Redis for caching and background jobs
- Sidekiq for background processing
- DaisyUI + Tailwind CSS for styling
- Devise for authentication
- TinyMCE for rich text editing
- AI/LLM Integration (OpenAI, Claude, Gemini)

## Common Commands

### Development Setup
```bash
# Start all services
docker-compose up

# Run commands inside the web container
docker-compose exec web rake setup:dev
docker-compose exec web rake setup:health
docker-compose exec web rake setup:create_admin
docker-compose exec web rake setup:reset_db
```

### Code Quality
```bash
# Run all quality checks
docker-compose exec web rake quality:all

# Run specific checks
docker-compose exec web rake quality:rubocop
docker-compose exec web rake quality:brakeman
docker-compose exec web rake quality:bundle_audit

# Auto-fix RuboCop issues
docker-compose exec web rake quality:fix
```

### Testing
```bash
# Run all tests
docker-compose exec web rails test

# Run system tests
docker-compose exec web rails test:system

# Run specific test file
docker-compose exec web rails test test/models/user_test.rb
```

### Browser Testing (Self-Healing)
```bash
# Test a specific page
docker-compose exec web rake browser:test[/users]

# Test with full diagnostics (includes Docker logs)
docker-compose exec web rake browser:diagnose[/app_projects/new]

# Test and get errors formatted for fixing
docker-compose exec web rake browser:test_for_fix[/dashboard]

# Run a user journey test
docker-compose exec web rake browser:journey[user_registration]
docker-compose exec web rake browser:journey[user_login]
docker-compose exec web rake browser:journey[create_project]
docker-compose exec web rake browser:journey[feature_walkthrough]

# Take a screenshot
docker-compose exec web rake browser:screenshot[/]
```

### Development Server
```bash
# Start all Docker services (Rails app, Sidekiq, PostgreSQL, Redis)
docker-compose up

# Start in detached mode
docker-compose up -d

# View logs
docker-compose logs -f web
docker-compose logs -f sidekiq

# Stop all services
docker-compose down
```

### Database
```bash
# Setup database
docker-compose exec web bin/rails db:setup

# Run migrations
docker-compose exec web bin/rails db:migrate

# Seed database
docker-compose exec web bin/rails db:seed

# Console
docker-compose exec web bin/rails console
```

### Generators
```bash
# Generate API controller
docker-compose exec web rails generate api_controller product

# Generate service object
docker-compose exec web rails generate service payment_processor

# Generate standard scaffold with UUID and DaisyUI styling
docker-compose exec web rails generate scaffold product name:string price:decimal

# Generate controller with DaisyUI views
docker-compose exec web rails generate controller products index show

# Generate AI-enhanced model
docker-compose exec web rails generate ai_model product --description="A product in our e-commerce store"

# Generate AI-enhanced model with attributes
docker-compose exec web rails generate ai_model user --description="User account" --attributes="name:string email:string"
```

### DaisyUI Generator Features
All Rails generators now automatically create DaisyUI-styled views:
- **Responsive layouts** with Tailwind CSS grid and flexbox
- **Beautiful forms** with DaisyUI form controls and validation styling
- **Interactive tables** with hover effects and action buttons
- **Flash messages** styled as DaisyUI alerts
- **Navigation breadcrumbs** for better UX
- **Empty states** with helpful messaging and call-to-action buttons

### Application Customization
```bash
# Rename application (updates all files including database names)
docker-compose exec web rake app:rename[MyNewApp]

# Generate new secret keys
docker-compose exec web rake setup:generate_secrets

# Setup Kamal deployment configuration
rake kamal:setup INTERACTIVE=true
```

### AI/LLM Commands
```bash
# Check LLM configuration and provider status
docker-compose exec web rake llm:status

# Test all configured providers
docker-compose exec web rake llm:test

# Clear LLM response cache
docker-compose exec web rake llm:clear_cache

# Show LLM configuration help
docker-compose exec web rake llm:help
```

### Email Testing (Development)
```bash
# View sent emails in development
# Visit http://localhost:3000/letter_opener after sending emails
# All emails sent in development are captured and viewable in the web interface
```

### Chat Functionality

The application includes a comprehensive real-time chat system with the following features:
- Real-time messaging using ActionCable WebSockets
- Chat threads with multiple participants
- Typing indicators and read receipts
- Markdown support for rich text formatting
- ViewComponent-based UI for reusability

```bash
# Access chat interface
# Visit http://localhost:3000/chat

# View chat component documentation
# docs/features/chat-component.md

# Test chat in Lookbook (interactive demo)
# Visit http://localhost:3000/lookbook/inspect/chat/live_demo_component/default

# Create a new chat thread (Rails console)
docker-compose exec web rails console
user = User.first
thread = ChatThread.create!(name: 'General Discussion', created_by: user)
thread.add_participant(user)

# Add messages to a thread
thread.messages.create!(user: user, content: 'Hello, world!')

# Mark thread as read for a user
thread.mark_as_read_for(user)

# Get unread count
thread.unread_count_for(user)

# Add chat to any model (polymorphic association)
# See docs/features/chat-component.md for implementation details
```

## Documentation Directory

**The `/docs` directory contains comprehensive documentation for developers and AI code agents:**

- `/docs/README.md` - Central navigation hub for all documentation
- `/docs/architecture/overview.md` - System architecture and design decisions
- `/docs/patterns/ui-components.md` - UI component patterns using ViewComponent and DaisyUI
- `/docs/deployment/docker.md` - Docker container management and deployment
- `/docs/features/ai-integration.md` - AI/LLM service integration details
- `/docs/workflows/feature-development.md` - Development workflow patterns
- `/docs/reference/commands.md` - Common commands cheatsheet
- `/docs/app-projects/` - Generated PRDs, tasks, and project artifacts
  - `/docs/app-projects/generated/` - Auto-generated project documentation
  - Each project has its own subdirectory with PRD, tasks, Claude prompts, and artifacts

**When working on this project, refer to the `/docs` directory for:**
- Understanding existing patterns and conventions
- Finding examples of UI components and layouts
- Learning the deployment and development workflows
- Accessing generated project documentation and requirements

## Important Files

### Configuration
- `config/initializers/app_config.rb` - Application configuration
- `.env.example` - Environment variables template
- `config/database.yml` - Database configuration (uses UUID)

### Custom Generators
- `lib/generators/api_controller/` - API controller generator
- `lib/generators/service/` - Service object generator
- `lib/generators/ai_model/` - AI-enhanced model generator

### AI/LLM Integration
- `app/services/llm/` - LLM adapter interfaces and implementations
- `lib/tasks/llm.rake` - LLM management and testing tasks

### Development Tools
- `config/initializers/development_tools.rb` - Debug helpers and logging
- `lib/tasks/setup.rake` - Setup and utility tasks
- `lib/tasks/quality.rake` - Code quality tasks
- **Email Testing**: letter_opener_web available at `/letter_opener` in development

### Templates
- `Dockerfile.example` - Docker configuration
- `docker-compose.example.yml` - Docker Compose setup
- `.github/workflows/ci.yml.example` - CI/CD pipeline
- `.rubocop.yml.example` - Code style configuration

## Architecture Patterns

### Models
- All models use UUID primary keys
- Use concerns for shared behavior
- Follow Rails conventions

### Controllers
- Inherit from ApplicationController
- Use before_action for authentication
- Return JSON for API endpoints

### Services
- Use service objects for complex business logic
- Generate with: `rails generate service service_name`
- Follow single responsibility principle

### Jobs
- Use Sidekiq for background processing
- Place in `app/jobs/`
- Use `perform_later` for async execution

## Environment Variables

Key environment variables (see `.env.example` for full list):
- `APP_NAME` - Application name
- `DATABASE_URL` - Database connection
- `REDIS_URL` - Redis connection
- `RAILS_MASTER_KEY` - Rails credentials key

### AI/LLM Environment Variables
- `LLM_PROVIDER` - Primary AI provider (openai, claude, gemini)
- `OPENAI_API_KEY` - OpenAI API key
- `CLAUDE_API_KEY` - Anthropic Claude API key
- `GEMINI_API_KEY` - Google Gemini API key
- `LLM_FALLBACK_PROVIDERS` - Comma-separated fallback providers
- `LLM_CACHE_ENABLED` - Enable response caching (default: true)
- `OPENAI_MODEL` - OpenAI model selection (default: gpt-4o-mini)
- `CLAUDE_MODEL` - Claude model selection (default: claude-3-5-sonnet-20241022)
- `GEMINI_MODEL` - Gemini model selection (default: gemini-2.5-pro)

## Feature Flags

Configure features in `config/initializers/app_config.rb`:
- `config.features.registration_enabled`
- `config.features.social_login_enabled`
- `config.features.maintenance_mode`

## Testing Strategy

- Unit tests for models and services
- Integration tests for controllers
- System tests for end-to-end workflows
- Use fixtures for test data

## Deployment

### Heroku (Recommended)
1. **One-Click Deploy**: Use the "Deploy to Heroku" button in README
2. **Manual Setup**:
   ```bash
   heroku create your-app-name
   heroku addons:create heroku-postgresql:essential-0
   heroku addons:create heroku-redis:mini
   git push heroku main
   ```

### Docker Deployment
The application includes a Docker setup with:
- **Web service**: Rails application server
- **Sidekiq service**: Background job processor
- **PostgreSQL**: Database with pgvector extension
- **Redis**: Caching and job queue storage

To deploy:
1. Build and push your Docker image
2. Set production environment variables
3. Deploy using docker-compose or your container orchestration platform

## Troubleshooting

### Common Issues
- **Database connection errors**: Check `DATABASE_URL` in `.env`
- **Redis connection errors**: Check `REDIS_URL` in `.env`
- **Asset compilation errors**: Run `yarn install` and `rails assets:precompile`
- **Permission errors**: Check file permissions with `rake setup:health`

### Debug Helpers
- Enable debug mode: `DEBUG=true` in `.env`
- Console helpers: `u('email')` to create users, `show_config` for current config
- Bullet gem: `BULLET_ENABLED=true` to detect N+1 queries

## Docker Development Workflow

### Starting the Application
```bash
# Start all services
docker-compose up

# Or in detached mode
docker-compose up -d

# Check service status
docker-compose ps
```

### Accessing the Application
- Rails app: http://localhost:3000
- Database: localhost:5432
- Redis: localhost:6379

### Running Commands
All Rails commands must be run inside the web container:
```bash
# Rails console
docker-compose exec web rails console

# Run migrations
docker-compose exec web rails db:migrate

# Run tests
docker-compose exec web rails test
```

## Browser Testing Workflow

When implementing a new feature:

1. **Implement the feature**
2. **Test it immediately**:
   ```bash
   docker-compose exec web rake browser:test_for_fix[/path/to/feature]
   ```
3. **If errors are found**, the output will show:
   - JavaScript console errors
   - Network errors (404s, 500s)
   - Rails application errors
   - Suggested fixes
4. **Fix the errors** based on the output
5. **Re-test** to verify fixes:
   ```bash
   docker-compose exec web rake browser:test[/path/to/feature]
   ```
6. **Run a full journey** to ensure end-to-end functionality:
   ```bash
   docker-compose exec web rake browser:journey[feature_walkthrough]
   ```

### Understanding Test Output

The `browser:test_for_fix` command provides structured output:
```
=== BROWSER TEST RESULT ===
URL: /app_projects/new
Status: failed
Errors: 2

Error 1:
  Type: javascript_error
  Message: Cannot read property 'addEventListener' of null
  File: /assets/application.js
  Line: 125

Error 2:
  Type: network_error
  Message: GET /api/undefined returned 404

Suggested Fixes:
  1. Check if the element exists before accessing 'addEventListener'
  2. Check if the route exists in config/routes.rb

Screenshot: tmp/screenshots/error_app_projects_new.png
=== END BROWSER TEST RESULT ===
```

## Contributing

1. Run quality checks before committing: `rake quality:all`
2. Ensure tests pass: `rails test`
3. **Test your changes with browser testing**: `rake browser:test_for_fix[/your/feature]`
4. Follow the existing code style
5. Update documentation when adding features