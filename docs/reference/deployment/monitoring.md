# Performance Monitoring and Error Tracking

This Rails application includes comprehensive performance monitoring and error tracking capabilities designed to help you identify performance bottlenecks, track errors, and maintain application health.

## Overview

The monitoring system consists of:
- **Performance Monitoring** - Track request times, database queries, and memory usage
- **Error Tracking** - Capture and log application errors with context
- **Health Checks** - Monitor system health and dependencies
- **Metrics Collection** - Gather application and infrastructure metrics
- **Rake Tasks** - Command-line tools for monitoring and maintenance

## Quick Start

### Enable Performance Tracking

Add the performance tracking concern to your controllers:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include PerformanceTracking
end
```

### Run Health Checks

```bash
# Check application health
rake monitoring:health

# View performance metrics
rake monitoring:metrics

# Generate detailed report
rake monitoring:report
```

## Performance Monitoring

### Automatic Request Tracking

The system automatically tracks:
- **Request duration** - Total time to process requests
- **Database queries** - Number and timing of SQL queries
- **Memory usage** - Memory allocation and GC statistics
- **Slow requests** - Requests exceeding threshold (default: 1 second)

### Controller-Level Tracking

```ruby
class ProductsController < ApplicationController
  include PerformanceTracking
  
  # Track specific actions with detailed monitoring
  track_action_performance :index, :show
  
  # Skip tracking for lightweight actions
  skip_performance_tracking :ping, :health
end
```

### Performance Headers (Development)

In development mode, response headers include performance data:
- `X-Runtime` - Request processing time
- `X-Memory-Usage` - Memory usage delta
- `X-DB-Queries` - Number of database queries

### Slow Request Detection

Automatically logs requests exceeding the threshold:

```ruby
# Set custom threshold (default: 1.0 second)
ENV['SLOW_REQUEST_THRESHOLD'] = '0.5'
```

Slow requests are logged with:
- Controller and action name
- Request duration
- Request parameters (sanitized)
- User information
- Browser and IP details

## Error Tracking

### Automatic Error Handling

Errors are automatically:
- Logged with full context
- Sent to Rails error reporting
- Tracked with request metadata
- Rendered with appropriate responses

### Error Context

Each error includes:
- Controller and action information
- Request parameters (excluding sensitive data)
- User identification
- Browser and network details
- Request ID for tracing

### Custom Error Tracking

```ruby
begin
  risky_operation
rescue CustomError => e
  Rails.error.handle(e, context: { operation: 'custom_operation' })
end
```

## Health Monitoring

### Application Health Checks

```bash
rake monitoring:health
```

Checks:
- **Database connectivity** - Verifies database connection
- **Redis connectivity** - Tests cache and session store
- **Sidekiq status** - Background job processor health
- **Disk space** - Available storage
- **Memory usage** - RAM and GC statistics

### Continuous Monitoring

```bash
# Real-time monitoring dashboard
rake monitoring:watch
```

Displays live updates of:
- Active job queues
- Memory usage
- Database connections
- Recent log entries

## Metrics Collection

### Database Metrics

- Database size and growth
- Table sizes and row counts
- Query performance statistics
- Connection pool usage

### Cache Metrics

- Redis memory usage
- Cache hit/miss ratios
- Key distribution
- Client connections

### Job Metrics

- Processed job counts
- Failed job analysis
- Queue depths
- Processing times

### System Metrics

- Memory allocation patterns
- Garbage collection frequency
- Log file sizes
- Temporary file cleanup

## Maintenance Tasks

### Cleanup Operations

```bash
# Clean old logs and temporary files
rake monitoring:cleanup
```

Removes:
- Log files older than 7 days
- Temporary files older than 1 day
- Application cache

### Issue Detection

```bash
# Check for potential issues
rake monitoring:check
```

Identifies:
- Large log files (>100MB)
- High failed job counts
- Large database sizes
- Performance bottlenecks

### Performance Reports

```bash
# Generate comprehensive report
rake monitoring:report
```

Creates timestamped reports with:
- System information
- Database statistics
- Job processing metrics
- Memory and GC analysis

## External Service Integration

### Error Tracking Services

The monitoring system is designed to integrate with popular error tracking services:

#### Sentry Integration

```ruby
# config/initializers/sentry.rb
if Rails.env.production?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 0.1
  end
end
```


### Metrics Services

Integration examples for metrics collection:

#### Event Analytics with Ahoy

```ruby
# Track user events and behavior
ahoy.track "Product Viewed", product_id: @product.id
ahoy.track "Purchase Completed", {
  product_id: @product.id,
  amount: @product.price,
  user_id: current_user.id
}

# Track performance metrics
ahoy.track "Slow Request", {
  controller: controller_name,
  action: action_name,
  duration: duration,
  user_id: current_user&.id
}
```

#### Data Visualization with Blazer

```ruby
# Create custom dashboards and charts
# Visit /blazer for interactive data exploration

# Example queries for performance monitoring:
# - Average response time by controller
# - Top slow requests in the last 24 hours  
# - User activity patterns and conversion funnels
# - Error frequency by endpoint
```

#### New Relic Integration

```ruby
# In performance tracking concern
if defined?(NewRelic)
  NewRelic::Agent.record_metric("Custom/Controller/#{controller_name}/#{action_name}", duration)
end
```

## Configuration

### Environment Variables

- `SLOW_REQUEST_THRESHOLD` - Slow request threshold in seconds (default: 1.0)
- `SENTRY_DSN` - Sentry error tracking endpoint
- `NEW_RELIC_LICENSE_KEY` - New Relic monitoring key

### Performance Thresholds

Customize monitoring thresholds:

```ruby
# config/application.rb
config.performance_monitoring = {
  slow_request_threshold: 1.0,    # seconds
  slow_query_threshold: 0.5,      # seconds
  memory_threshold: 100,          # MB
  log_retention_days: 7           # days
}
```

## Development Monitoring

### Debug Information

In development mode:
- Memory usage tracking
- N+1 query detection (with Bullet gem)
- Performance headers in responses
- Detailed GC statistics

### Performance Profiling

```ruby
# Use detailed tracking for specific actions
class ProductsController < ApplicationController
  track_action_performance :index  # Enhanced monitoring
end
```

## Production Monitoring

### Performance Notifications

- Rails ActiveSupport notifications
- Custom event tracking
- External service integration
- Slack/email alerts for critical issues

### Log Analysis

Structured logging for:
- Request performance metrics
- Error tracking with context
- Slow query identification
- Memory usage patterns

## Best Practices

### Performance Optimization

1. **Monitor Key Metrics**
   - Response times < 200ms for most requests
   - Database queries < 50ms average
   - Memory growth patterns
   - Cache hit rates > 90%

2. **Error Handling**
   - Log errors with sufficient context
   - Sanitize sensitive information
   - Provide meaningful error responses
   - Track error patterns and trends

3. **Maintenance**
   - Regular log file cleanup
   - Monitor disk space usage
   - Check for failed background jobs
   - Review performance reports weekly

### Alerting Strategy

Set up alerts for:
- **Critical**: Application errors, database connectivity
- **Warning**: Slow requests, high memory usage
- **Info**: Job completion, maintenance activities

## Troubleshooting

### High Memory Usage

1. Check GC statistics: `rake monitoring:metrics`
2. Look for memory leaks in logs
3. Review object allocation patterns
4. Consider memory profiling tools

### Slow Requests

1. Identify slow endpoints: `rake monitoring:check`
2. Analyze database query patterns
3. Check for N+1 query problems
4. Review caching strategy

### Database Issues

1. Monitor connection pool usage
2. Check for long-running queries
3. Review table sizes and indexes
4. Analyze query execution plans

### Background Job Problems

1. Check Sidekiq dashboard
2. Review failed job patterns
3. Monitor queue depths
4. Check Redis connectivity

## Security Considerations

### Sensitive Data

- Passwords are automatically filtered from logs
- Request parameters are sanitized
- User data is anonymized in external services
- IP addresses are logged but can be masked

### Access Control

- Monitoring endpoints should be protected
- Error details are limited in production
- Debug information is development-only
- External service keys are environment-controlled

## Monitoring Dashboard

For a complete monitoring solution, consider implementing:
- Grafana dashboards for metrics visualization
- ElasticSearch for log aggregation
- Prometheus for metrics collection
- Kibana for log analysis

The monitoring system provides the foundation and can be extended with these tools for comprehensive observability.