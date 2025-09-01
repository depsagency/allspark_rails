# Architecture Overview

This document provides a high-level overview of the Rails 8.0 application template architecture, designed for rapid development with AI integration capabilities.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Web Browser                              │
│                    (DaisyUI + Stimulus.js)                      │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS
┌─────────────────────────┴───────────────────────────────────────┐
│                      Rails Application                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Controllers Layer                       │   │
│  │  ApplicationController → Feature Controllers             │   │
│  │  API Controllers → JSON Responses                        │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                     │
│  ┌─────────────────────────┴───────────────────────────────┐   │
│  │                    Service Layer                          │   │
│  │  Business Logic → LLM Services → Background Jobs         │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                     │
│  ┌─────────────────────────┴───────────────────────────────┐   │
│  │                     Models Layer                          │   │
│  │  ApplicationRecord → Domain Models (UUID-based)          │   │
│  └─────────────────────────┬───────────────────────────────┘   │
└────────────────────────────┼────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────┴────────┐  ┌────────┴────────┐  ┌───────┴────────┐
│   PostgreSQL   │  │      Redis      │  │  File Storage  │
│   (Primary DB) │  │  (Cache/Queue)  │  │ (Active Storage)│
└────────────────┘  └─────────────────┘  └────────────────┘
```

## Core Technologies

### Backend Stack
- **Rails 8.0**: Latest Rails with modern defaults
- **Ruby 3.3+**: Latest stable Ruby version
- **PostgreSQL**: Primary database with UUID support
- **Redis**: Caching, ActionCable, and Sidekiq queues
- **Sidekiq**: Background job processing

### Frontend Stack
- **Hotwire**: Turbo + Stimulus for SPA-like experience
- **DaisyUI**: Component library built on Tailwind CSS
- **ViewComponent**: Component-based view architecture
- **esbuild**: Fast JavaScript bundling

### AI/LLM Integration
- **Multi-provider Support**: OpenAI, Claude, Gemini
- **Adapter Pattern**: Swappable AI providers
- **Service Objects**: Clean abstraction for AI operations

## Key Architectural Decisions

### 1. UUID Primary Keys
All models use UUIDs as primary keys for better distributed system compatibility:
```ruby
create_table :users, id: :uuid do |t|
  # ...
end
```
Benefits:
- No ID conflicts in distributed systems
- Better security (IDs not guessable)
- Easier data migration and replication

### 2. Service Object Pattern
Complex business logic is encapsulated in service objects:
```
app/services/
├── llm/                    # AI/LLM services
├── concerns/               # Shared service functionality
└── [feature]_service.rb    # Feature-specific services
```

### 3. ViewComponent Architecture
UI components are built as reusable ViewComponents:
```
app/components/
├── base_component.rb       # Base class with common functionality
├── ui/                     # UI components
└── forms/                  # Form-specific components
```

### 4. Real-time Features with ActionCable
WebSocket connections for live updates:
- Notifications
- Progress tracking
- Presence indicators
- Live data updates

## Directory Structure

```
rails-template/
├── app/
│   ├── channels/          # ActionCable channels
│   ├── components/        # ViewComponents
│   ├── controllers/       # Request handlers
│   ├── helpers/           # View helpers
│   ├── javascript/        # Stimulus controllers
│   ├── jobs/              # Background jobs
│   ├── models/            # Domain models
│   ├── policies/          # Authorization policies
│   ├── services/          # Business logic
│   └── views/             # View templates
├── config/
│   ├── initializers/      # App configuration
│   └── environments/      # Environment configs
├── db/
│   ├── migrate/           # Database migrations
│   └── seeds.rb           # Seed data
├── docs/                  # Documentation
├── lib/
│   ├── generators/        # Custom generators
│   └── tasks/             # Rake tasks
├── public/                # Static files
├── spec/                  # RSpec tests
└── storage/               # Active Storage files
```

## Request Flow

1. **Browser Request** → Nginx/Load Balancer
2. **Rails Router** → Matches route to controller
3. **Controller** → Handles request, calls services
4. **Service Layer** → Executes business logic
5. **Model Layer** → Database operations
6. **View Rendering** → ViewComponents + Templates
7. **Response** → HTML/JSON back to browser

## Database Design Principles

### UUID Usage
Every table uses UUID primary keys:
```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  self.implicit_order_column = :created_at
  
  # UUID is set at database level
end
```

### Soft Deletes
Important models use soft deletes for data recovery:
```ruby
class User < ApplicationRecord
  include Discard::Model
  # Records are marked as discarded, not deleted
end
```

### JSON Columns
Flexible data storage using JSONB:
```ruby
class AppProject < ApplicationRecord
  # settings stored as JSONB for flexibility
  store_accessor :settings, :theme, :features
end
```

## Security Architecture

### Authentication
- **Devise**: Complete authentication solution
- **Session-based**: Secure cookie storage
- **2FA Ready**: TOTP support built-in

### Authorization
- **Pundit**: Policy-based authorization
- **Role-based**: Admin, user, guest roles
- **Resource-level**: Per-record permissions

### API Security
- **Token Authentication**: For API endpoints
- **Rate Limiting**: Rack::Attack configuration
- **CORS**: Configured for API access

## Performance Considerations

### Caching Strategy
1. **Fragment Caching**: ViewComponent caching
2. **Redis Cache**: Application-level caching
3. **HTTP Caching**: Proper cache headers

### Background Processing
- **Sidekiq**: Efficient job processing
- **Job Priorities**: Critical vs. background
- **Retry Logic**: Automatic retry with backoff

### Database Optimization
- **Indexes**: Proper indexing strategy
- **N+1 Prevention**: Bullet gem in development
- **Query Optimization**: EXPLAIN analysis

## Scalability Design

### Horizontal Scaling
- Stateless application design
- Redis for shared state
- Database connection pooling

### Asset Pipeline
- CDN-ready asset compilation
- Fingerprinted assets
- Efficient bundling with esbuild

### Background Jobs
- Separate worker processes
- Queue prioritization
- Job idempotency

## Development Workflow

### Local Development
```bash
# Start all services
bin/dev

# Run specific services
rails server
bundle exec sidekiq
```

### Docker Development
```bash
# Full stack with Docker
docker-compose up

# Run commands in container
docker-compose exec web rails console
```

### Testing Strategy
- **RSpec**: Unit and integration tests
- **System Tests**: Full browser testing
- **CI/CD**: GitHub Actions integration

## Deployment Architecture

### Heroku (Recommended)
- **Web Dyno**: Rails application
- **Worker Dyno**: Sidekiq processing
- **Postgres**: Database addon
- **Redis**: Redis addon

### Docker Deployment
- **Multi-stage Build**: Optimized images
- **Health Checks**: Automated monitoring
- **Environment Config**: Via environment variables

## Monitoring and Observability

### Application Monitoring
- **Performance Tracking**: Custom middleware
- **Error Tracking**: Exception notification
- **Metrics Collection**: Business metrics

### Infrastructure Monitoring
- **Health Endpoints**: /health and /status
- **Log Aggregation**: Structured logging
- **Alerts**: Critical issue notification