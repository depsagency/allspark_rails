# Dependabot Management Guide

This guide explains how to efficiently manage Dependabot pull requests in the Allspark Rails template.

## Overview

Dependabot automatically creates pull requests to update your dependencies. With our configuration, updates are grouped by category and scheduled weekly to reduce noise.

## Configuration

The Dependabot configuration is located at `.github/dependabot.yml` and includes:

- **Weekly updates** on Mondays at 9 AM
- **Grouped updates** by category (development tools, testing tools, Rails ecosystem, etc.)
- **Separate limits** for Ruby (10 PRs) and JavaScript (5 PRs) dependencies

## Management Scripts

### 1. Check Dependabot Status

```bash
bin/dependabot-status
```

This script provides:
- Overview of all open Dependabot PRs
- Grouping by ecosystem (Ruby, JavaScript, etc.)
- Status of CI checks (ready, failed, running)
- Age of PRs (highlights those older than 7 days)
- Recommendations for action

### 2. Merge Dependabot PRs

```bash
# Interactive mode (default) - prompts for each PR
bin/merge-dependabot

# Process all PRs without prompting
bin/merge-dependabot --all

# List PRs only, don't process
bin/merge-dependabot --list

# Skip running tests
bin/merge-dependabot --skip-tests
```

The merge script:
- Checks out each PR branch
- Runs tests (unless skipped)
- Merges if tests pass
- Deletes the branch after merging
- Returns to main branch

## Workflow Recommendations

### Weekly Routine

1. **Monday Morning**: Check for new Dependabot PRs
   ```bash
   bin/dependabot-status
   ```

2. **Review Ready PRs**: Look for PRs with passing CI
   ```bash
   bin/merge-dependabot --list
   ```

3. **Merge Safe Updates**: Process PRs interactively
   ```bash
   bin/merge-dependabot
   ```

### Best Practices

1. **Review Major Updates Carefully**
   - Check changelogs for breaking changes
   - Test thoroughly in development
   - Consider creating a separate branch for major updates

2. **Handle Failed PRs**
   - Check CI logs for failure reasons
   - Fix issues locally if simple
   - Comment on PR if you need to defer

3. **Group Related Updates**
   - Our configuration automatically groups related gems
   - Consider merging all updates in a group together

## Dependency Groups

Our configuration groups dependencies as follows:

### Ruby Groups
- **development-tools**: debug, ruby-lsp, rubocop, brakeman
- **testing-tools**: rspec, capybara, factory_bot, faker, lookbook
- **rails-ecosystem**: rails, turbo-rails, stimulus-rails, solid_* gems
- **deployment-tools**: kamal, thruster, puma
- **google-apis**: All Google API gems
- **background-jobs**: sidekiq, redis

### JavaScript Groups
- **javascript-tools**: Hotwired tools, esbuild, tailwindcss, daisyui

## Troubleshooting

### GitHub CLI Not Installed
```bash
brew install gh
gh auth login
```

### PR Won't Merge
- Check if branch has conflicts
- Ensure all CI checks pass
- Try merging manually on GitHub

### Tests Fail Locally but Pass on CI
- Ensure your local environment matches CI
- Check for missing dependencies
- Run `bundle install` and `yarn install`

## Security Considerations

- Always review security updates promptly
- Check for CVE references in PR descriptions
- Prioritize patches for vulnerabilities
- Run `bundle audit` after updates

## Manual Dependency Updates

If you need to update a specific dependency manually:

```bash
# Update a specific gem
bundle update gem_name

# Update all gems in a group
bundle update --group development

# Update JavaScript dependencies
yarn upgrade package_name
```

## Ignoring Updates

To ignore specific dependencies, add them to the `ignore` section in `.github/dependabot.yml`:

```yaml
ignore:
  - dependency-name: "rails"
    versions: ["7.x", "8.x"]
```