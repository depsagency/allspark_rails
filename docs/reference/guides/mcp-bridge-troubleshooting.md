# MCP Bridge Troubleshooting Guide

## Overview

This guide helps you diagnose and fix common issues with the MCP Bridge integration in AllSpark.

## Quick Diagnostics

### Check Bridge Status

```bash
# In Docker development environment
docker-compose exec web rake mcp_bridge:status

# In production
heroku run rake mcp_bridge:status -a your-app
```

### Health Check

```bash
# Check if health monitor is running
docker-compose exec web rake mcp_bridge:health_check

# View recent health monitor logs
docker-compose logs sidekiq | grep "McpHealthMonitor"
```

## Common Issues

### 1. Process Spawn Failures

**Symptoms:**
- "Failed to spawn MCP server" errors
- Tools list returns empty array
- Server status shows "error"

**Causes and Solutions:**

#### Command Not Found
```bash
# Check if the MCP server command exists
docker-compose exec web which linear-mcp
docker-compose exec web which npx

# For Node-based MCP servers, ensure Node.js is available
docker-compose exec web node --version
```

**Solution:**
- Install the MCP server package in your Docker image
- Add the command to your Dockerfile:
```dockerfile
RUN npm install -g @linear/mcp-server
```

#### Environment Variables Missing
```bash
# Check if required environment variables are set
docker-compose exec web env | grep LINEAR_API_KEY
```

**Solution:**
- Add missing environment variables to your `.env` file
- Restart the application after updating environment variables

#### Permission Issues
```bash
# Check if the command is executable
docker-compose exec web ls -la $(which linear-mcp)
```

**Solution:**
```bash
# Make the command executable
docker-compose exec web chmod +x /path/to/mcp-command
```

### 2. Communication Timeouts

**Symptoms:**
- "MCP request timeout" errors
- Tools execute but take too long
- Intermittent failures

**Diagnosis:**
```bash
# Check timeout configuration
docker-compose exec web rails console
> Rails.application.config.mcp_bridge[:process_timeout]
```

**Solutions:**

#### Increase Timeout
```bash
# In .env file
MCP_BRIDGE_PROCESS_TIMEOUT=60  # Increase from 30 to 60 seconds
```

#### Check MCP Server Performance
```bash
# Test MCP server directly
docker-compose exec web linear-mcp --help

# Check server response time
time docker-compose exec web linear-mcp
```

#### Monitor Process Health
```bash
# Check if processes are becoming unresponsive
docker-compose exec web rake mcp_bridge:status
```

### 3. JSON-RPC Errors

**Symptoms:**
- "Invalid JSON response" errors
- "Message ID mismatch" errors
- Malformed response errors

**Diagnosis:**
```bash
# Enable debug logging
MCP_BRIDGE_LOG_LEVEL=debug

# Check logs for raw JSON-RPC messages
docker-compose logs web | grep "MCP Bridge"
```

**Solutions:**

#### Verify MCP Server Protocol
```bash
# Test MCP server with raw JSON-RPC
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}}},"id":1}' | docker-compose exec -T web linear-mcp
```

#### Check for Buffer Issues
- Some MCP servers may have buffering issues with stdio
- Try adding `force: true` to stdio operations (requires code changes)

### 4. Memory Leaks

**Symptoms:**
- Gradually increasing memory usage
- "Out of memory" errors
- Slow performance over time

**Diagnosis:**
```bash
# Monitor memory usage
docker stats allspark-web-1

# Check process count
docker-compose exec web rake mcp_bridge:status | grep "Active processes"

# Run memory benchmark
docker-compose exec web rspec spec/benchmarks/mcp_bridge_benchmarks.rb -t memory
```

**Solutions:**

#### Tune Process Limits
```bash
# In .env file
MCP_BRIDGE_MAX_PROCESSES=5  # Reduce if memory usage is high
MCP_BRIDGE_PROCESS_IDLE_TIMEOUT=300  # Clean up idle processes sooner
```

#### Force Garbage Collection
```bash
# In production, consider periodic GC
heroku run rake mcp_bridge:force_gc -a your-app
```

#### Monitor Process Cleanup
```bash
# Check if processes are being cleaned up properly
docker-compose logs sidekiq | grep "process cleanup"
```

### 5. Configuration Validation Errors

**Symptoms:**
- "Configuration validation failed" errors
- "Command not allowed for security" errors
- "Missing required environment variables" errors

**Common Issues:**

#### Blocked Commands
```bash
# Check if your command is in the blocklist
grep -A 10 "DANGEROUS_COMMANDS" app/services/mcp_bridge_manager.rb
```

**Solution:**
- Use a wrapper script if you need to run blocked commands
- Ensure your command is safe and not in the security blocklist

#### Invalid Configuration Format
```ruby
# Valid configuration format
{
  "command" => "linear-mcp",
  "args" => [],
  "env" => {
    "LINEAR_API_KEY" => "your-key"
  }
}
```

#### Shell Operators
```bash
# These will be blocked:
"echo; cat /etc/passwd"
"ls | grep secret"
"command && other-command"
```

**Solution:**
- Use simple commands without shell operators
- Create wrapper scripts if complex operations are needed

### 6. Circuit Breaker Activation

**Symptoms:**
- "Circuit breaker is open" errors
- Repeated failures followed by blocked requests
- Service becomes unavailable

**Diagnosis:**
```bash
# Check circuit breaker status
docker-compose exec web rails console
> McpBridgeManager.new.instance_variable_get(:@circuit_breakers)
```

**Solutions:**

#### Wait for Recovery
- Circuit breaker automatically resets after cooldown period (default: 1 minute)
- Monitor logs for "Circuit breaker reset" messages

#### Fix Underlying Issues
- Address the root cause of repeated failures
- Check MCP server configuration and connectivity

#### Reset Circuit Breaker Manually
```ruby
# In Rails console (development only)
bridge = McpBridgeManager.new
bridge.instance_variable_get(:@circuit_breakers).clear
```

### 7. Performance Issues

**Symptoms:**
- Slow tool execution
- High CPU usage
- Timeouts under load

**Diagnosis:**
```bash
# Run performance benchmarks
docker-compose exec web rspec spec/benchmarks/mcp_bridge_benchmarks.rb

# Check resource usage
docker stats allspark-web-1
```

**Solutions:**

#### Optimize Process Pool
```bash
# Tune process pool settings
MCP_BRIDGE_MAX_PROCESSES=10  # Increase for more concurrent users
MCP_BRIDGE_CACHE_TTL=300     # Cache tool lists longer
```

#### Enable JSON Optimization
```ruby
# Add to Gemfile if not present
gem 'oj'

# Restart application to use faster JSON parsing
```

#### Monitor Tool Execution
```bash
# Check slow tools
docker-compose logs web | grep "Tool execution time" | sort -k7 -n
```

## Production-Specific Issues

### 1. Heroku Deployment

**Issue:** MCP servers not found in production

**Solution:**
```bash
# Add MCP servers to your buildpack
echo "node_buildpack" >> .buildpacks
echo "npm install -g @linear/mcp-server" >> package.json
```

**Issue:** Timeout in production

**Solution:**
```bash
# Increase timeout for production
heroku config:set MCP_BRIDGE_PROCESS_TIMEOUT=60 -a your-app
```

### 2. Docker Production

**Issue:** Permission denied errors

**Solution:**
```dockerfile
# In Dockerfile
RUN useradd -m appuser
USER appuser
```

**Issue:** Missing dependencies

**Solution:**
```dockerfile
# Install all MCP server dependencies
RUN npm install -g @linear/mcp-server @github/mcp-server
```

### 3. Load Balancer Issues

**Issue:** Process affinity problems with multiple instances

**Solution:**
- Implement Redis-based process tracking (advanced)
- Use sticky sessions if possible
- Consider external MCP service

## Monitoring and Alerting

### Log Analysis

```bash
# Check for common error patterns
docker-compose logs web | grep -E "(ERROR|WARN)" | grep "MCP Bridge"

# Monitor process lifecycle
docker-compose logs web | grep "MCP process"

# Track tool execution patterns
docker-compose logs web | grep "Tool execution"
```

### Metrics to Monitor

1. **Process Count**
   - Active MCP processes
   - Process spawn rate
   - Process failure rate

2. **Performance**
   - Tool execution time
   - Process spawn time
   - Memory usage

3. **Errors**
   - Timeout rate
   - Configuration errors
   - Circuit breaker activations

### Alerting Setup

```yaml
# Example Prometheus alerts
- alert: MCPBridgeHighErrorRate
  expr: rate(mcp_bridge_errors_total[5m]) > 0.1
  for: 2m
  annotations:
    summary: "High error rate in MCP Bridge"

- alert: MCPBridgeProcessLeaks
  expr: mcp_bridge_active_processes > 20
  for: 5m
  annotations:
    summary: "Possible process leak in MCP Bridge"
```

## Emergency Procedures

### Complete Reset

```bash
# Stop all MCP processes
docker-compose exec web rails console
> McpProcessPoolService.instance.shutdown_all_processes

# Clear all caches
docker-compose exec web rake mcp_bridge:clear_cache

# Restart application
docker-compose restart web sidekiq
```

### Disable MCP Bridge

```bash
# Temporary disable
heroku config:set MCP_BRIDGE_ENABLED=false -a your-app

# Or in .env file
MCP_BRIDGE_ENABLED=false
```

### Rollback Deployment

```bash
# Heroku
heroku rollback -a your-app

# Docker
docker-compose down
git checkout previous-commit
docker-compose up -d --build
```

## Getting Help

### Debug Information to Collect

When reporting issues, include:

1. **Environment Info**
   ```bash
   docker-compose exec web rails console
   > Rails.env
   > RUBY_VERSION
   > Rails.version
   ```

2. **Configuration**
   ```bash
   # Sanitized configuration (remove sensitive data)
   docker-compose exec web rails console
   > Rails.application.config.mcp_bridge
   ```

3. **Error Logs**
   ```bash
   docker-compose logs web | tail -100
   docker-compose logs sidekiq | grep MCP | tail -50
   ```

4. **System State**
   ```bash
   docker stats
   docker-compose exec web rake mcp_bridge:status
   ```

### Support Channels

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Check `/docs/deployment/mcp-bridge-deployment.md`
- **Community**: Discord/Slack community channels

### Performance Reports

```bash
# Generate comprehensive report
docker-compose exec web rspec spec/benchmarks/mcp_bridge_benchmarks.rb
cat tmp/mcp_bridge_performance_report.json
```

Include performance reports when reporting performance issues.