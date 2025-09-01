# Debugging Workflow

This guide covers debugging techniques and tools for the AllSpark application.

## Development Environment Debugging

### Rails Console
The Rails console is your primary debugging tool:

```bash
# Start console
docker-compose exec web rails console

# With specific environment
docker-compose exec web rails console -e test

# Sandbox mode (rollback on exit)
docker-compose exec web rails console --sandbox
```

### Common Console Commands
```ruby
# Reload console without restarting
reload!

# Pretty print objects
pp User.first

# Check database connection
ActiveRecord::Base.connection.active?

# View SQL queries
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Disable SQL logging
ActiveRecord::Base.logger = nil
```

## Debugging Techniques

### Using Debugger
Add breakpoints in your code:

```ruby
# Using debug gem (Ruby 3.1+)
require 'debug'

def process_payment(order)
  debugger  # Execution stops here
  amount = calculate_total(order)
  charge_card(amount)
end

# Using binding.pry (alternative)
require 'pry'

def process_payment(order)
  binding.pry  # Execution stops here
  amount = calculate_total(order)
  charge_card(amount)
end
```

### Debug Commands
```ruby
# In debugger
next      # Execute next line
step      # Step into method
continue  # Continue execution
up        # Move up the stack
down      # Move down the stack
list      # Show current code
pp var    # Pretty print variable
```

## Logging and Output

### Rails Logger
```ruby
# In application code
Rails.logger.debug "Processing order: #{order.id}"
Rails.logger.info "Payment successful for amount: #{amount}"
Rails.logger.warn "Retrying failed API call"
Rails.logger.error "Payment failed: #{e.message}"

# Tagged logging
Rails.logger.tagged('PaymentService') do
  Rails.logger.info "Starting payment process"
  # ... code ...
  Rails.logger.info "Payment completed"
end

# Custom log file
payment_logger = Logger.new(Rails.root.join('log', 'payments.log'))
payment_logger.info "Payment processed: #{payment.to_json}"
```

### Development Helpers
```ruby
# In views
<%= debug @user %>
<%= @user.inspect %>

# In controllers
logger.debug "Params: #{params.inspect}"

# Console output
puts "=" * 50
pp object.attributes
puts "=" * 50
```

## Browser Debugging

### Chrome DevTools
1. **Network Tab**: Monitor API requests
2. **Console**: Check JavaScript errors
3. **Elements**: Inspect DOM and CSS
4. **Sources**: Debug JavaScript with breakpoints

### Rails Development Tools
```erb
<!-- Show params in development -->
<% if Rails.env.development? %>
  <div class="fixed bottom-4 right-4 p-4 bg-gray-900 text-white rounded-lg max-w-md overflow-auto max-h-96">
    <h4 class="font-bold mb-2">Debug Info</h4>
    <pre><%= params.to_yaml %></pre>
  </div>
<% end %>
```

## Database Debugging

### Query Analysis
```ruby
# Enable query logging
ActiveRecord::Base.verbose_query_logs = true

# Explain query plan
User.where(active: true).explain

# Count queries in block
query_count = 0
ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
  query_count += 1
end

# Your code here
process_users

puts "Queries executed: #{query_count}"
```

### N+1 Query Detection
```ruby
# Using Bullet gem
# In development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
end

# Manual detection
# Bad - N+1 query
users = User.all
users.each do |user|
  puts user.posts.count  # Query for each user
end

# Good - Eager loading
users = User.includes(:posts)
users.each do |user|
  puts user.posts.size  # No additional queries
end
```

## Background Job Debugging

### Sidekiq Debugging
```ruby
# In job class
class PaymentJob < ApplicationJob
  def perform(payment_id)
    Rails.logger.tagged("PaymentJob:#{payment_id}") do
      Rails.logger.info "Starting payment processing"
      
      payment = Payment.find(payment_id)
      
      # Add debug output
      Rails.logger.debug "Payment details: #{payment.attributes}"
      
      process_payment(payment)
    rescue => e
      Rails.logger.error "Payment failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end
end

# Test job in console
PaymentJob.new.perform(payment_id)

# Check Sidekiq queues
require 'sidekiq/api'
Sidekiq::Queue.new.size
Sidekiq::RetrySet.new.size
Sidekiq::DeadSet.new.size
```

## Error Tracking

### Better Errors (Development)
The `better_errors` gem provides an enhanced error page:
- Interactive REPL at error point
- Source code preview
- Variable inspection
- Stack trace navigation

### Exception Handling
```ruby
# Global exception handling
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound do |e|
    logger.error "Record not found: #{e.message}"
    render_404
  end

  rescue_from StandardError do |e|
    logger.error "Unhandled error: #{e.message}"
    logger.error e.backtrace.join("\n")
    
    if Rails.env.development?
      raise e  # Re-raise in development
    else
      render_500
    end
  end
end
```

## Performance Debugging

### Rack Mini Profiler
Shows performance metrics in development:

```ruby
# Temporarily disable
Rack::MiniProfiler.config.enabled = false

# Profile specific code
Rack::MiniProfiler.step('expensive_operation') do
  perform_expensive_operation
end

# Add custom timing
mp_timer = Rack::MiniProfiler.start_step('custom_timing')
# ... code to measure ...
Rack::MiniProfiler.finish_step(mp_timer)
```

### Memory Profiling
```ruby
# Check memory usage
require 'objspace'
ObjectSpace.memsize_of_all

# Find memory leaks
GC.start
before = ObjectSpace.count_objects
# ... suspicious code ...
GC.start
after = ObjectSpace.count_objects
diff = after.merge(before) { |k, v1, v2| v1 - v2 }
pp diff.select { |k, v| v > 0 }
```

## Testing Debugging

### RSpec Debugging
```ruby
# Focus on specific test
it 'processes payment', focus: true do
  # Test code
end

# Run only focused tests
bundle exec rspec --tag focus

# Add debug output
it 'calculates total' do
  puts "Order items: #{order.items.inspect}"
  total = order.calculate_total
  puts "Calculated total: #{total}"
  expect(total).to eq(100)
end

# Use pry in tests
require 'pry'
it 'complex test' do
  binding.pry  # Drops into debugger
  expect(result).to be_valid
end
```

### System Test Debugging
```ruby
# Take screenshot
take_screenshot

# Pause test
pause

# Save and open page
save_and_open_page

# Debug JavaScript
page.driver.browser.manage.logs.get(:browser).each do |log|
  puts log.message
end
```

## Docker Debugging

### Container Debugging
```bash
# View container logs
docker-compose logs -f web
docker-compose logs --tail=100 sidekiq

# Access container shell
docker-compose exec web bash

# Check running processes
docker-compose exec web ps aux

# View environment variables
docker-compose exec web printenv

# Check disk usage
docker-compose exec web df -h
```

### Database Debugging
```bash
# Access database console
docker-compose exec postgres psql -U postgres allspark_development

# Common PostgreSQL commands
\l              # List databases
\dt             # List tables
\d+ users       # Describe table
\x              # Toggle expanded output
SELECT * FROM users LIMIT 1;
```

## Common Issues and Solutions

### 1. Assets Not Loading
```bash
# Clear asset cache
docker-compose exec web rails assets:clobber
docker-compose exec web rails assets:precompile

# Check asset pipeline
docker-compose exec web rails assets:reveal
```

### 2. Database Connection Issues
```ruby
# Check connection
ActiveRecord::Base.connection.active?

# Reset connection
ActiveRecord::Base.connection.reconnect!

# View connection config
pp ActiveRecord::Base.connection_config
```

### 3. Cache Issues
```bash
# Clear all caches
docker-compose exec web rails tmp:clear
docker-compose exec web rails cache:clear

# Clear specific cache
Rails.cache.delete('specific_key')
Rails.cache.clear
```

### 4. Route Debugging
```bash
# View all routes
docker-compose exec web rails routes

# Search routes
docker-compose exec web rails routes | grep user

# Test route in console
app.users_path
app.user_url(1)
```

## Debug Checklist

When encountering an issue:

1. **Check the logs**
   - Application logs: `tail -f log/development.log`
   - Docker logs: `docker-compose logs -f`
   - Browser console for JavaScript errors

2. **Isolate the problem**
   - Can you reproduce it?
   - Does it happen in test environment?
   - Is it data-specific?

3. **Use debugging tools**
   - Add `debugger` or `binding.pry`
   - Check database queries
   - Inspect network requests

4. **Test the fix**
   - Write a failing test first
   - Fix the issue
   - Ensure test passes

5. **Document the solution**
   - Add comments explaining the fix
   - Update documentation if needed
   - Share knowledge with team