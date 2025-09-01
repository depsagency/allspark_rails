# Style Guide

This directory contains coding standards and style guides for the Allspark project.

## Language-Specific Guides

### Ruby Style Guide
- Follow the [Ruby Style Guide](https://rubystyle.guide/)
- Use RuboCop for enforcement (see `.rubocop.yml`)
- Run `rake quality:rubocop` to check compliance

### JavaScript/TypeScript Style Guide
- ES6+ syntax preferred
- Use ESLint for enforcement
- Prefer functional components in React

### CSS/SCSS Style Guide
- Use Tailwind CSS utilities first
- Follow DaisyUI component patterns
- Keep custom CSS minimal and well-documented

## General Principles

### Code Organization
- Keep files focused and single-purpose
- Use meaningful file and variable names
- Group related functionality

### Documentation
- Document complex logic
- Keep comments concise and relevant
- Update documentation when changing code

### Testing
- Write tests for new features
- Maintain existing test coverage
- Use descriptive test names

### Git Conventions
- Use clear, descriptive commit messages
- Reference issue numbers when applicable
- Keep commits focused on single changes

## Rails-Specific Conventions

### Models
- Use UUID primary keys
- Implement proper validations
- Use concerns for shared behavior

### Controllers
- Keep controllers thin
- Use service objects for complex logic
- Follow RESTful conventions

### Views
- Use ViewComponents for reusable UI
- Follow DaisyUI patterns
- Keep logic out of views

## UI/UX Guidelines

### Component Usage
- Prefer DaisyUI components
- Maintain consistent spacing
- Follow responsive design patterns

### Accessibility
- Include proper ARIA labels
- Ensure keyboard navigation
- Test with screen readers

### Performance
- Optimize images and assets
- Use lazy loading where appropriate
- Monitor bundle sizes