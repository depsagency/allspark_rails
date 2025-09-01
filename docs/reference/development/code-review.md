# Code Review Workflow

This guide outlines the code review process and best practices for the AllSpark project.

## Code Review Process

### 1. Pre-Review Checklist
Before requesting a review, ensure:

- [ ] All tests pass locally
- [ ] Code follows style guidelines (run `rake quality:all`)
- [ ] Commit messages are clear and descriptive
- [ ] PR description explains the changes
- [ ] Documentation is updated if needed
- [ ] No debugging code or console.log statements
- [ ] Database migrations are reversible

### 2. Creating a Pull Request

#### PR Title Format
```
[Type] Brief description

Examples:
[Feature] Add user authentication with Devise
[Fix] Resolve N+1 query in projects index
[Refactor] Extract payment processing to service object
[Docs] Update API documentation for v2 endpoints
```

#### PR Description Template
```markdown
## Description
Brief description of what this PR does.

## Why
Explain the motivation for these changes.

## Changes
- List key changes
- Highlight any breaking changes
- Note any new dependencies

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manually tested in development
- [ ] Browser testing passed

## Screenshots
(If applicable, add screenshots of UI changes)

## Related Issues
Closes #123
```

### 3. Review Guidelines

#### For Reviewers

**What to Look For:**

1. **Correctness**
   - Does the code do what it claims?
   - Are edge cases handled?
   - Is error handling appropriate?

2. **Security**
   - No SQL injection vulnerabilities
   - Proper authentication/authorization
   - Sensitive data not logged
   - Strong parameters used

3. **Performance**
   - No N+1 queries
   - Appropriate use of database indexes
   - Efficient algorithms
   - Proper caching

4. **Maintainability**
   - Code is readable and self-documenting
   - Follows established patterns
   - Appropriate abstraction level
   - No code duplication

5. **Testing**
   - Adequate test coverage
   - Tests are meaningful
   - Edge cases tested
   - Tests follow AAA pattern

#### Review Comments

**Good Review Comments:**
```ruby
# Constructive with explanation
"This could cause an N+1 query. Consider using `includes(:user)` to eager load the association."

# Suggests improvement
"This logic might be clearer as a separate method. What about extracting it to `calculate_discount`?"

# Asks clarifying questions
"I'm not sure I understand why we need this check. Could you explain the use case?"

# Provides examples
"Instead of:
  users.map { |u| u.name }.join(', ')
Consider:
  users.pluck(:name).join(', ')
This avoids loading full User objects."
```

**Poor Review Comments:**
```ruby
# Too vague
"This doesn't look right."

# Not constructive
"Why would you do it this way?"

# Nitpicking without value
"Missing period at end of comment."
```

## Code Review Checklist

### Architecture & Design
- [ ] Follows MVC patterns appropriately
- [ ] Business logic in appropriate layer (models/services)
- [ ] No logic in views
- [ ] Proper separation of concerns
- [ ] Follows RESTful conventions

### Ruby/Rails Specific
- [ ] Uses Rails conventions and helpers
- [ ] Avoids reinventing Rails features
- [ ] Proper use of ActiveRecord features
- [ ] Follows Ruby idioms
- [ ] No deprecated methods

### Database
- [ ] Migrations are reversible
- [ ] Appropriate indexes added
- [ ] Foreign key constraints where needed
- [ ] No data migrations in schema migrations
- [ ] Column defaults set appropriately

### Security
- [ ] Strong parameters used
- [ ] No mass assignment vulnerabilities
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] CSRF protection enabled
- [ ] Authentication/authorization checks

### Performance
- [ ] N+1 queries avoided
- [ ] Database queries optimized
- [ ] Caching used appropriately
- [ ] No unnecessary database hits
- [ ] Background jobs for heavy operations

### Testing
- [ ] Tests cover happy path
- [ ] Tests cover error cases
- [ ] Tests are isolated and fast
- [ ] No skipped or pending tests
- [ ] Factories used instead of fixtures

### Frontend
- [ ] Follows Stimulus conventions
- [ ] No inline JavaScript
- [ ] Accessible markup
- [ ] Mobile responsive
- [ ] Cross-browser compatible

### Documentation
- [ ] Code comments where necessary
- [ ] API documentation updated
- [ ] README updated if needed
- [ ] Complex logic explained
- [ ] CHANGELOG updated

## Common Issues to Watch For

### 1. N+1 Queries
```ruby
# Bad
@posts.each do |post|
  puts post.user.name  # N+1 query
end

# Good
@posts = Post.includes(:user)
@posts.each do |post|
  puts post.user.name  # No additional queries
end
```

### 2. Logic in Views
```erb
<!-- Bad -->
<% if @user.created_at > 30.days.ago && @user.posts.count > 5 %>
  <span>Active user</span>
<% end %>

<!-- Good -->
<% if @user.active? %>
  <span>Active user</span>
<% end %>
```

### 3. Fat Controllers
```ruby
# Bad
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    
    if @user.save
      # Complex logic here
      send_welcome_email
      create_default_settings
      track_analytics_event
      notify_admin_team
      
      redirect_to @user
    else
      render :new
    end
  end
end

# Good
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    
    if @user.save
      UserOnboardingService.new(@user).process
      redirect_to @user
    else
      render :new
    end
  end
end
```

### 4. Missing Error Handling
```ruby
# Bad
def process_payment
  charge = Stripe::Charge.create(
    amount: @order.total_cents,
    currency: 'usd',
    source: params[:token]
  )
  @order.update!(status: 'paid')
end

# Good
def process_payment
  charge = Stripe::Charge.create(
    amount: @order.total_cents,
    currency: 'usd',
    source: params[:token]
  )
  @order.update!(status: 'paid')
rescue Stripe::CardError => e
  logger.error "Payment failed: #{e.message}"
  @order.update!(status: 'payment_failed')
  raise
rescue StandardError => e
  logger.error "Unexpected error: #{e.message}"
  raise
end
```

## Automated Checks

### Pre-commit Hooks
Set up git hooks to run checks before commit:

```bash
# .git/hooks/pre-commit
#!/bin/sh
echo "Running quality checks..."

# RuboCop
bundle exec rubocop

# Brakeman security check
bundle exec brakeman -q

# Tests
bundle exec rspec --fail-fast

if [ $? -ne 0 ]; then
  echo "Pre-commit checks failed. Please fix issues before committing."
  exit 1
fi
```

### CI/CD Checks
Automated checks that run on every PR:

1. **Test Suite**: All tests must pass
2. **Code Quality**: RuboCop, Brakeman, Bundle Audit
3. **Coverage**: Maintain >80% test coverage
4. **Documentation**: Ensure docs are generated
5. **Build**: Verify Docker build succeeds

## Review Response Times

### SLA Guidelines
- **First review**: Within 24 hours
- **Follow-up reviews**: Within 12 hours
- **Urgent fixes**: Within 2 hours

### Review Priorities
1. **Critical**: Security fixes, production bugs
2. **High**: Features blocking other work
3. **Normal**: Regular features and improvements
4. **Low**: Refactoring, documentation updates

## Post-Review

### After Approval
1. Ensure CI passes
2. Squash commits if needed
3. Update branch with main
4. Merge using GitHub merge button
5. Delete feature branch

### After Merge
1. Verify deployment succeeded
2. Test feature in staging/production
3. Update related documentation
4. Close related issues
5. Notify team if needed

## Best Practices

### For Authors
- Keep PRs small and focused
- Respond to feedback professionally
- Provide context in PR description
- Test thoroughly before review
- Be open to suggestions

### For Reviewers
- Be constructive and kind
- Explain the "why" behind suggestions
- Approve if no blocking issues
- Use "Request changes" sparingly
- Acknowledge good code

### Communication
- Use threads for discussions
- Resolve conversations when addressed
- Ask questions if unclear
- Suggest pairing for complex issues
- Thank reviewers for their time

## Review Tools

### GitHub Features
- **Suggested changes**: Propose specific code changes
- **Code navigation**: Jump to definitions
- **Review comments**: Group related feedback
- **Draft reviews**: Collect thoughts before submitting

### VS Code Extensions
- **GitLens**: View git blame and history
- **Pull Request**: Review PRs in editor
- **GitHub Copilot**: AI-assisted reviews

### Command Line
```bash
# Check out PR locally
gh pr checkout 123

# View PR diff
gh pr diff 123

# Comment on PR
gh pr comment 123 --body "Looks good!"

# Approve PR
gh pr review 123 --approve
```