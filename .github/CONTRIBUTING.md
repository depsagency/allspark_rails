# Contributing to AllSpark

First off, thank you for considering contributing to AllSpark! It's people like you that make AllSpark such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed and expected**
* **Include screenshots if relevant**
* **Include your environment details** (OS, Ruby version, Rails version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a detailed description of the suggested enhancement**
* **Provide specific examples to demonstrate the enhancement**
* **Describe the current behavior and expected behavior**
* **Explain why this enhancement would be useful**

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code follows the style guidelines
6. Issue that pull request!

## Development Process

### Setup Development Environment

1. Fork and clone the repository
```bash
git clone https://github.com/yourusername/allspark-template.git
cd allspark-template
```

2. Set up the development environment
```bash
cp .env.example .env
docker-compose up
docker-compose exec web rails db:setup
```

3. Create a feature branch
```bash
git checkout -b feature/my-new-feature
```

### Code Style

#### Ruby Style Guide

We use RuboCop to enforce Ruby style guidelines:

```bash
# Check your code
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

Key conventions:
- Use 2 spaces for indentation
- Prefer single quotes for strings without interpolation
- Keep methods under 10 lines when possible
- Write descriptive variable and method names
- Add comments for complex logic

#### JavaScript Style Guide

- Use ES6+ features
- Prefer `const` and `let` over `var`
- Use Stimulus.js for JavaScript behavior
- Keep Stimulus controllers focused and single-purpose

#### CSS/SCSS Style Guide

- Use Tailwind CSS utility classes
- Use DaisyUI components when available
- Avoid custom CSS when possible
- Keep component styles in ViewComponents

### Testing

All new features must include tests:

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/user_test.rb

# Run system tests
rails test:system
```

Test guidelines:
- Write unit tests for models and services
- Write integration tests for controllers
- Write system tests for user workflows
- Maintain test coverage above 80%
- Use fixtures for test data

### Commit Messages

We follow conventional commit messages:

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(auth): add two-factor authentication
fix(api): handle null response in user endpoint
docs(readme): update installation instructions
```

### Documentation

- Update README.md for user-facing changes
- Update code comments for complex logic
- Update API documentation for endpoint changes
- Add entries to CHANGELOG.md for notable changes

## Project Structure

```
allspark/
├── app/
│   ├── controllers/     # Request handlers
│   ├── models/          # Data models
│   ├── views/           # View templates
│   ├── components/      # ViewComponents
│   ├── services/        # Business logic
│   └── jobs/            # Background jobs
├── config/              # Configuration files
├── db/                  # Database files
├── docs/                # Documentation
├── lib/                 # Custom libraries
├── public/              # Static files
├── spec/                # RSpec tests
├── test/                # Minitest tests
└── docker-compose.yml   # Docker configuration
```

## Release Process

1. Update version number
2. Update CHANGELOG.md
3. Create a pull request
4. After merge, create a release tag
5. GitHub Actions will handle the rest

## Getting Help

- Check the [documentation](../docs/)
- Search [existing issues](https://github.com/yourusername/allspark-template/issues)
- Ask in [discussions](https://github.com/yourusername/allspark-template/discussions)
- Contact maintainers

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project README

Thank you for contributing to AllSpark! 🎉