# Browser Testing Quick Reference

## Essential Commands

### 🧪 Testing Pages
```bash
# Quick test - just check if page works
docker-compose exec web rake browser:test[/path]

# Detailed test - get errors formatted for fixing
docker-compose exec web rake browser:test_for_fix[/path]

# Full diagnostics - includes Docker logs
docker-compose exec web rake browser:diagnose[/path]
```

### 🚀 User Journeys
```bash
# Run predefined journeys
docker-compose exec web rake browser:journey[user_registration]
docker-compose exec web rake browser:journey[user_login]
docker-compose exec web rake browser:journey[create_project]
docker-compose exec web rake browser:journey[feature_walkthrough]
```

### 📸 Screenshots
```bash
# Capture any page
docker-compose exec web rake browser:screenshot[/path]
```

### 📋 Logs
```bash
# Recent logs (last 5 min)
docker-compose exec web rake logs:recent

# Logs from last N minutes
docker-compose exec web rake logs:recent[10]

# Find errors
docker-compose exec web rake logs:errors[60]

# Container health
docker-compose exec web rake docker:health
```

## Quick Workflow

```bash
# 1. After implementing a feature
docker-compose exec web rake browser:test_for_fix[/new-feature]

# 2. Fix any errors shown

# 3. Verify fix worked
docker-compose exec web rake browser:test[/new-feature]

# 4. Run full journey test
docker-compose exec web rake browser:journey[feature_walkthrough]
```

## Error Output Format

```
=== BROWSER TEST RESULT ===
URL: /path
Status: failed/passed
Errors: N

Error 1:
  Type: javascript_error/network_error/rails_error
  Message: Detailed error message
  File: /path/to/file
  Line: 123

Suggested Fixes:
  1. Specific fix suggestion
  2. Another fix suggestion

Screenshot: tmp/screenshots/error_path.png
=== END BROWSER TEST RESULT ===
```

## Pro Tips

- **Start with** `test_for_fix` - it gives the most useful output
- **Screenshots** are saved in `tmp/screenshots/`
- **Journey tests** ensure end-to-end functionality
- **Log commands** help when browser tests aren't enough
- **Rebuild Docker** if Chrome errors: `docker-compose build web`

## Common Fixes

| Error | Quick Fix |
|-------|-----------|
| `Cannot read property 'X' of null` | Check element exists: `if (element) { element.X }` |
| `GET /api/X returned 404` | Add route to `config/routes.rb` |
| `Rails error detected` | Check `docker-compose exec web rake logs:recent` |
| `is not defined` | Check script load order or missing import |
| `Failed to fetch` | Check CORS settings or API endpoint |

## Writing Custom Journeys

1. Create file: `test/browser/journeys/my_journey.rb`
2. Use the journey DSL:
   ```ruby
   journey :my_journey do
     setup_session
     step "Do something" do
       visit "/path"
       fill_in "Field", with: "Value"
       click_button "Submit"
       expect_page_to_have("Success")
     end
     teardown_session
   end
   ```
3. Run it: `docker-compose exec web rake browser:journey[my_journey]`