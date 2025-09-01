# Dual Sidekiq Architecture

## Overview

Allspark implements a dual Sidekiq architecture to handle background jobs in different container contexts:

- **Builder Sidekiq**: Handles AI generation, notifications, and UI-related jobs 
- **Target Sidekiq**: Handles development environment jobs, Claude sessions, and file operations

## Architecture Benefits

### Queue Separation with Shared Redis
Both Sidekiq instances use the same Redis server (redis:6379/0) but with different queue namespaces:

**Builder Queues:**
- `builder_default` - General Builder container jobs
- `builder_ai` - AI generation jobs (PRD, tasks, prompts)
- `builder_notifications` - User notifications

**Target Queues:**
- `target_development` - Development environment setup
- `target_claude` - Claude Code session management  
- `target_files` - File operations in workspace

### Container Configuration

#### Builder Sidekiq Container
```yaml
builder-sidekiq:
  environment:
    CONTAINER_ROLE: builder_sidekiq
    SIDEKIQ_QUEUES: builder_default,builder_ai,builder_notifications
  volumes:
    - .:/app  # Full Rails application access
```

#### Target Sidekiq Container  
```yaml
target-sidekiq:
  environment:
    CONTAINER_ROLE: target_sidekiq
    SIDEKIQ_QUEUES: target_development,target_claude,target_files
  volumes:
    - .:/app  # Rails app access
    - workspace_shared:/app/workspace  # Shared workspace
```

## Queue Helper Service

The `QueueHelper` module automatically routes jobs to appropriate queues based on container role:

```ruby
# Routes AI generation jobs to builder_ai queue in Builder context
queue_name = QueueHelper.queue_for(:ai_generation)

# Routes Claude session jobs to target_claude queue in Target context  
queue_name = QueueHelper.queue_for(:claude_session)
```

## Usage in Jobs

Jobs can specify their target context:

```ruby
class AiGenerationJob < ApplicationJob
  queue_as QueueHelper.queue_for(:ai_generation)
  
  def perform(project)
    # Runs in Builder context
  end
end

class ClaudeSessionJob < ApplicationJob  
  queue_as QueueHelper.queue_for(:claude_session)
  
  def perform(environment)
    # Runs in Target context with workspace access
  end
end
```

## Implementation Status

✅ **Completed:**
- Docker Compose configuration for dual Sidekiq
- Entrypoint script with container role detection
- Queue Helper service for automatic routing
- Builder Sidekiq working correctly

🔄 **In Progress:**
- Target Sidekiq configuration (requires Rails app loading fix)

## Next Steps

1. Fix Target Sidekiq Rails environment loading
2. Implement job queue separation in existing jobs
3. Add monitoring for both Sidekiq instances
4. Test job routing between contexts

## Benefits

- **Clean Separation**: Builder handles UI/AI jobs, Target handles development jobs
- **Resource Efficiency**: Shared Redis server with namespace isolation  
- **Scalability**: Each Sidekiq can be scaled independently
- **Context Isolation**: Jobs run in appropriate container environment