# Release Process

This guide outlines the release process for the AllSpark application.

## Release Types

### Semantic Versioning
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (0.X.0): New features, backwards compatible
- **PATCH** (0.0.X): Bug fixes, backwards compatible

### Release Cadence
- **Major releases**: Quarterly (as needed)
- **Minor releases**: Monthly
- **Patch releases**: As needed for critical fixes
- **Hotfixes**: Immediate for security/critical bugs

## Pre-Release Checklist

### 1. Code Preparation
- [ ] All feature branches merged to `main`
- [ ] No pending PRs for this release
- [ ] All tests passing on `main`
- [ ] Code quality checks passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated

### 2. Testing
- [ ] Full regression test suite passed
- [ ] Browser testing completed
- [ ] Performance benchmarks acceptable
- [ ] Security scan completed
- [ ] Staging environment tested

### 3. Dependencies
- [ ] All dependencies up to date
- [ ] Security vulnerabilities addressed
- [ ] License compliance verified
- [ ] Gemfile.lock committed

## Release Process

### 1. Create Release Branch
```bash
# Create release branch from main
git checkout main
git pull origin main
git checkout -b release/v1.2.0

# Update version number
# Edit config/application.rb
module Allspark
  VERSION = "1.2.0"
end

# Commit version bump
git add .
git commit -m "Bump version to 1.2.0"
```

### 2. Update CHANGELOG
```markdown
# CHANGELOG.md

## [1.2.0] - 2024-01-20

### Added
- New feature X (#123)
- Enhancement Y (#124)

### Changed
- Improved performance of Z (#125)
- Updated UI for better accessibility (#126)

### Fixed
- Bug in payment processing (#127)
- Memory leak in background jobs (#128)

### Security
- Updated dependencies to patch CVE-2024-1234

### Deprecated
- Old API endpoint /v1/users (use /v2/users)

### Removed
- Unused legacy code
```

### 3. Final Testing
```bash
# Run full test suite
bundle exec rspec
bundle exec rails test:system

# Run security checks
bundle exec brakeman
bundle exec bundler-audit

# Check for broken links
bundle exec rake test:links

# Verify migrations
bundle exec rails db:migrate:status
```

### 4. Create Release PR
```bash
# Push release branch
git push origin release/v1.2.0

# Create PR via GitHub CLI
gh pr create \
  --title "Release v1.2.0" \
  --body "$(cat .github/RELEASE_TEMPLATE.md)" \
  --base main
```

### 5. Deploy to Staging
```bash
# Deploy release branch to staging
heroku deploy release/v1.2.0 --app allspark-staging

# Or using GitHub Actions
gh workflow run deploy-staging.yml --ref release/v1.2.0
```

### 6. Final Approval
- [ ] QA team sign-off
- [ ] Product owner approval
- [ ] Security team review (major releases)
- [ ] Performance benchmarks verified

## Production Deployment

### 1. Merge Release Branch
```bash
# After approval, merge to main
git checkout main
git merge --no-ff release/v1.2.0
git push origin main

# Tag the release
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

### 2. Deploy to Production
```bash
# Automated deployment via GitHub Actions
# Triggered by tag push

# Or manual deployment
heroku deploy v1.2.0 --app allspark-production

# Verify deployment
curl https://api.allspark.dev/health
```

### 3. Database Migrations
```bash
# Run migrations (if any)
heroku run rails db:migrate --app allspark-production

# Verify migrations
heroku run rails db:migrate:status --app allspark-production
```

### 4. Post-Deployment Checks
- [ ] Application health check passing
- [ ] Key user flows working
- [ ] Error rates normal
- [ ] Performance metrics acceptable
- [ ] Background jobs processing

## Release Communication

### 1. GitHub Release
```bash
# Create GitHub release
gh release create v1.2.0 \
  --title "Release v1.2.0" \
  --notes-file CHANGELOG.md \
  --target main
```

### 2. Release Notes Template
```markdown
# AllSpark v1.2.0 Released!

We're excited to announce the release of AllSpark v1.2.0! This release includes several new features, improvements, and bug fixes.

## Highlights
- 🚀 **New Feature**: [Brief description]
- 🎨 **UI Improvement**: [Brief description]
- 🐛 **Bug Fix**: [Brief description]
- 🔒 **Security**: [Brief description]

## Breaking Changes
[List any breaking changes]

## Migration Guide
[Instructions for upgrading]

## Full Changelog
See the [full changelog](link-to-changelog) for complete details.

## Acknowledgments
Thanks to all contributors who made this release possible!
```

### 3. Notifications
- [ ] Update status page
- [ ] Send email to users (if applicable)
- [ ] Post to company blog
- [ ] Update documentation site
- [ ] Notify customer success team

## Rollback Procedure

### Immediate Rollback
```bash
# If issues discovered immediately
heroku rollback --app allspark-production

# Or revert to specific release
heroku releases:rollback v123 --app allspark-production
```

### Git Rollback
```bash
# Create hotfix from previous tag
git checkout -b hotfix/v1.1.1 v1.1.0

# Apply critical fix
# ... make changes ...

# Tag and deploy hotfix
git tag -a v1.1.1 -m "Hotfix: [description]"
git push origin v1.1.1
```

### Database Rollback
```bash
# Rollback last migration
heroku run rails db:rollback --app allspark-production

# Rollback to specific version
heroku run rails db:migrate VERSION=20240120123456
```

## Hotfix Process

### 1. Create Hotfix Branch
```bash
# Branch from production tag
git checkout -b hotfix/v1.2.1 v1.2.0

# Apply fix
# ... make minimal changes ...

# Test thoroughly
bundle exec rspec
```

### 2. Fast-Track Deployment
```bash
# Deploy to staging for quick verification
git push origin hotfix/v1.2.1
gh workflow run deploy-staging.yml --ref hotfix/v1.2.1

# After verification, tag and deploy
git tag -a v1.2.1 -m "Hotfix: Critical bug in payment processing"
git push origin v1.2.1
```

### 3. Merge Back
```bash
# Merge hotfix to main
git checkout main
git merge --no-ff hotfix/v1.2.1

# Merge to develop if exists
git checkout develop
git merge --no-ff hotfix/v1.2.1

# Delete hotfix branch
git branch -d hotfix/v1.2.1
```

## Monitoring Post-Release

### Key Metrics
Monitor for 24-48 hours post-release:

1. **Error Rates**
   - 500 errors
   - JavaScript errors
   - Failed background jobs

2. **Performance**
   - Response times
   - Database query times
   - Memory usage

3. **Business Metrics**
   - User registrations
   - Key feature usage
   - Transaction success rates

### Monitoring Commands
```bash
# View application logs
heroku logs --tail --app allspark-production

# Check error rates
heroku metrics --app allspark-production

# Database performance
heroku pg:diagnose --app allspark-production

# Redis status
heroku redis:info --app allspark-production
```

## Release Artifacts

### Required Documentation
1. **CHANGELOG.md**: User-facing changes
2. **RELEASES.md**: Technical release notes
3. **UPGRADE.md**: Upgrade instructions
4. **API_CHANGES.md**: API version changes

### Version File Updates
```ruby
# config/application.rb
module Allspark
  VERSION = "1.2.0"
  API_VERSION = "v2"
end

# package.json
{
  "version": "1.2.0"
}

# .version
1.2.0
```

## Automation

### GitHub Actions Workflow
```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Run tests
        run: |
          bundle exec rspec
          bundle exec rubocop
          
      - name: Build Docker image
        run: docker build -t allspark:${{ github.ref_name }} .
        
      - name: Deploy to production
        run: |
          # Deployment commands
          
      - name: Create GitHub release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            CHANGELOG.md
            RELEASES.md
```

### Release Scripts
```bash
#!/bin/bash
# scripts/release.sh

VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh VERSION"
  exit 1
fi

echo "Releasing version $VERSION..."

# Update version files
sed -i "" "s/VERSION = .*/VERSION = \"$VERSION\"/" config/application.rb
sed -i "" "s/\"version\": .*/\"version\": \"$VERSION\",/" package.json
echo $VERSION > .version

# Commit changes
git add .
git commit -m "Release v$VERSION"
git tag -a "v$VERSION" -m "Release v$VERSION"

# Push to remote
git push origin main
git push origin "v$VERSION"

echo "Release v$VERSION completed!"
```

## Post-Release Review

### Release Retrospective
After each major release:

1. **What went well?**
2. **What could be improved?**
3. **Were there any surprises?**
4. **Action items for next release**

### Metrics Review
- Release preparation time
- Deployment duration
- Issues discovered post-release
- Rollback incidents
- Customer feedback

### Documentation Updates
- Update runbooks
- Revise deployment guides
- Document lessons learned
- Update automation scripts