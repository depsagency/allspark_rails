# Browser Testing & Self-Healing - Usage Guide

This guide shows you how to use the browser testing functionality to dramatically speed up your development workflow.

## Quick Start Guide

### 1. Basic Page Testing
After implementing any feature, test it immediately:

```bash
# Test a specific page
docker-compose exec web rake browser:test[/users]

# Test the home page
docker-compose exec web rake browser:test[/]

# Test with full diagnostics (includes Docker logs)
docker-compose exec web rake browser:diagnose[/app_projects/new]
```

### 2. Testing for Claude Code (Self-Healing)
When you want structured output to fix errors:

```bash
# This gives you formatted output perfect for fixing errors
docker-compose exec web rake browser:test_for_fix[/app_projects/new]
```

Example output you'll see:
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
  Message: GET /api/projects returned 404

Suggested Fixes:
  1. Check if the element exists before accessing 'addEventListener'
  2. Check if the route exists in config/routes.rb

Screenshot: tmp/screenshots/error_app_projects_new.png
=== END BROWSER TEST RESULT ===
```

### 3. Running User Journey Tests
Test complete user workflows:

```bash
# Test user registration flow
docker-compose exec web rake browser:journey[user_registration]

# Test login/logout flow
docker-compose exec web rake browser:journey[user_login]

# Test creating a project
docker-compose exec web rake browser:journey[create_project]

# General feature walkthrough
docker-compose exec web rake browser:journey[feature_walkthrough]
```

### 4. Taking Screenshots
Capture the current state of any page:

```bash
# Take a screenshot of the home page
docker-compose exec web rake browser:screenshot[/]

# Screenshot a specific page
docker-compose exec web rake browser:screenshot[/users/edit]
```

### 5. Viewing Logs
Check recent logs from all containers:

```bash
# View logs from last 5 minutes (default)
docker-compose exec web rake logs:recent

# View logs from last 10 minutes
docker-compose exec web rake logs:recent[10]

# Search for errors in the last hour
docker-compose exec web rake logs:errors[60]

# Check container health
docker-compose exec web rake docker:health
```

## Typical Workflow

Here's how to use this after implementing a feature:

1. **Implement a feature** (e.g., adding a new form to `/products/new`)

2. **Test it immediately**:
   ```bash
   docker-compose exec web rake browser:test_for_fix[/products/new]
   ```

3. **If errors are found**, you'll see:
   - JavaScript console errors
   - Missing routes (404s)
   - Rails errors
   - Suggested fixes

4. **Fix the errors** based on the output

5. **Re-test to verify**:
   ```bash
   docker-compose exec web rake browser:test[/products/new]
   ```

6. **Run a full journey** to ensure end-to-end functionality:
   ```bash
   docker-compose exec web rake browser:journey[feature_walkthrough]
   ```

## Pro Tips

### For Quick Checks
```bash
# Just see if a page loads without errors
docker-compose exec web rake browser:test[/your/page]
```

### For Debugging
```bash
# Get everything - browser errors, logs, screenshots
docker-compose exec web rake browser:diagnose[/your/page]
```

### For Automated Fixing
```bash
# Get structured output Claude can parse and fix
docker-compose exec web rake browser:test_for_fix[/your/page]
```

### Check Logs When Stuck
```bash
# See what's happening in the containers
docker-compose exec web rake logs:recent[2]
```

## Real-World Example: Testing After Creating a New Feature

Let's say you just added a new "Reports" page:

```bash
# 1. Quick test
docker-compose exec web rake browser:test[/reports]

# 2. If it fails, get detailed info
docker-compose exec web rake browser:test_for_fix[/reports]

# 3. You might see:
# Error: GET /api/reports returned 404
# Suggested Fix: Check if the route exists in config/routes.rb

# 4. After fixing, verify
docker-compose exec web rake browser:test[/reports]

# 5. Test the full flow
docker-compose exec web rake browser:journey[feature_walkthrough]
```

This eliminates the back-and-forth of "try it", "it's broken", "fix it", "try again"!

## Understanding Error Types

### JavaScript Errors
```
Type: javascript_error
Message: Cannot read property 'addEventListener' of null
File: /assets/application.js
Line: 125
```
**What it means**: Your JavaScript is trying to use an element that doesn't exist.
**Quick fix**: Check if the element exists before using it.

### Network Errors
```
Type: network_error
Message: GET /api/users returned 404
```
**What it means**: You're calling an API endpoint that doesn't exist.
**Quick fix**: Add the route to `config/routes.rb` or fix the URL.

### Rails Errors
```
Type: rails_error
Message: NoMethodError
```
**What it means**: Your Ruby code has an error.
**Quick fix**: Check the logs for the full stack trace.

## Writing Your Own Journey Tests

Create a new file in `test/browser/journeys/my_feature.rb`:

```ruby
require_relative '../base_journey'

class MyFeatureJourney < BaseJourney
  include JourneyHelper

  journey :my_feature do
    setup_session

    begin
      step "Login" do
        login_as("admin@example.com", "password123")
      end

      step "Visit my feature" do
        visit "/my_feature"
        expect_no_errors
      end

      step "Interact with the page" do
        fill_in "Name", with: "Test"
        click_button "Save"
        expect_page_to_have("Success")
      end

    ensure
      teardown_session
    end
  end
end
```

Then run it:
```bash
docker-compose exec web rake browser:journey[my_feature]
```

## Troubleshooting

### "Chrome not found" Error
The Dockerfile already includes Chrome installation. If you see this error:
1. Rebuild the Docker image: `docker-compose build web`
2. Restart containers: `docker-compose down && docker-compose up -d`

### Tests Timing Out
Some pages take longer to load. The default timeout is 5 seconds. For slow pages:
1. Check if you have N+1 queries: `docker-compose exec web rake logs:recent`
2. Look for slow API calls in the network errors

### Can't See JavaScript Errors
The error collector tries multiple methods to get JS errors. If none work:
1. Check if Cuprite is properly configured
2. Try taking a screenshot to see what's on the page

## Benefits Over Manual Testing

**Before**: 
- Implement feature → User tests → Reports error → You fix → Repeat 3-5 times
- Time: 5-10 minutes per error

**After**:
- Implement feature → Run test → See all errors → Fix them → Verify
- Time: <30 seconds per error

## Integration with Development Workflow

### For Claude Code Users
1. After implementing any feature, immediately run:
   ```bash
   docker-compose exec web rake browser:test_for_fix[/path]
   ```
2. Fix any errors shown
3. Re-run to verify
4. Move on to the next feature

### For Human Developers
1. Use during development to catch errors early
2. Run journeys before committing to ensure nothing is broken
3. Use screenshots to debug visual issues

## Advanced Usage

### Custom Error Patterns
The system automatically detects common patterns and suggests fixes:
- "Cannot read property" → "Check if element exists"
- "404 errors" → "Add route to routes.rb"
- "500 errors" → "Check Rails logs"

### Parallel Testing
For faster testing of multiple pages:
```bash
# Test multiple pages in sequence
for page in / /users /app_projects; do
  docker-compose exec web rake browser:test[$page]
done
```

### CI Integration
Add to your CI pipeline:
```yaml
- name: Run browser tests
  run: |
    docker-compose exec -T web rake browser:journey[user_registration]
    docker-compose exec -T web rake browser:journey[feature_walkthrough]
```

## Summary

The browser testing framework transforms the development experience by:
1. **Immediate Feedback**: See errors within seconds of implementing
2. **Comprehensive Detection**: Catches JS, network, and Rails errors
3. **Actionable Output**: Provides specific fixes, not just error messages
4. **Visual Debugging**: Screenshots show exactly what went wrong
5. **Full Context**: Correlates browser errors with server logs

Stop the manual testing cycle. Let the browser testing framework find and help fix errors automatically!