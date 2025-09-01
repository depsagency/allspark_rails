# AI Code Examples and References

This document serves as a guide for AI assistants working with this Rails codebase, highlighting key locations where code examples, patterns, and implementation details can be found.

## Overview

This Rails 8.0 application includes extensive examples and documentation that can help AI assistants understand the codebase patterns, component structure, and implementation approaches. This guide outlines where to find these examples.

## Component Library and UI Examples

### Lookbook Integration

The application includes **Lookbook** integration for component development and documentation:

- **Access**: http://localhost:3000/lookbook (development only)
- **Location**: `app/components/previews/`
- **Purpose**: Live component previews, documentation, and interactive examples

All ViewComponents have corresponding Lookbook previews that demonstrate:
- Component usage patterns
- Available variants and options
- Real-world implementation examples
- Props and configuration options

### DaisyUI Component Examples

#### Welcome Page Showcase (Admin Only)
- **Location**: `app/views/pages/welcome.html.erb`
- **Access**: Admin users only
- **Purpose**: Comprehensive showcase of DaisyUI components in action
- **What to find**: 
  - Real-world component implementations
  - DaisyUI utility class usage
  - Layout patterns and responsive design
  - Component combinations and interactions

#### Dedicated UI Pages (Admin Only)
- **Themes Page**: Demonstrates theme switching and color systems
- **Icons Page**: Icon usage patterns and implementation
- **Component Pages**: Individual component demonstrations
- **Access**: All require admin privileges

### ViewComponent Library
- **Location**: `app/components/ui/`
- **Examples Available**:
  - `ButtonComponent` - Button variants, sizes, and states
  - `CardComponent` - Card layouts and content patterns
  - `BadgeComponent` - Status indicators and labels
  - `NavigationComponent` - Navigation patterns
  - `ThemeSwitcherComponent` - Theme switching implementation

## Architecture Examples

### Real-World Feature Implementation

#### AI-Powered App Builder (Complete Feature)
- **Location**: `app/controllers/app_projects_controller.rb`
- **Purpose**: Full-stack feature implementation example
- **Demonstrates**:
  - Complex form handling with wizard pattern
  - Background job integration with Sidekiq
  - AI/LLM service integration
  - Real-time updates with ActionCable
  - File export and generation
  - Modal implementations
  - Progress tracking and status management

#### Authentication and User Management
- **Location**: `app/controllers/users_controller.rb`
- **Demonstrates**: Devise integration patterns and user management

### Service Objects and LLM Integration
- **Location**: `app/services/llm/`
- **Examples**:
  - `PrdGeneratorService` - AI service integration patterns
  - `TaskDecompositionService` - Complex AI workflow
  - `PromptBuilderService` - Structured AI prompting
  - `AdapterFactory` - Provider abstraction patterns

### Background Job Patterns
- **Location**: `app/jobs/`
- **Examples**:
  - `AppProjectGenerationJob` - Complex background processing
  - Real-time progress updates
  - Error handling and retry logic
  - Multi-step workflow management

## Database and Model Patterns

### UUID Implementation
- **Location**: Throughout `app/models/`
- **Demonstrates**: UUID primary key usage patterns

### Model Relationships
- **Example Models**:
  - `AppProject` - Complex model with associations
  - `AiGeneration` - Tracking and metadata patterns
  - `User` - Devise integration with custom fields

### Enum Usage
- **Examples**: Status enums, type classifications
- **Location**: Various models showing enum best practices

## Configuration Examples

### Application Configuration
- **Location**: `config/initializers/app_config.rb`
- **Demonstrates**: Feature flags and environment-based configuration

### LLM Provider Configuration
- **Location**: `config/initializers/`
- **Examples**: Multi-provider API integration patterns

### Development Tools
- **Location**: `config/initializers/development_tools.rb`
- **Demonstrates**: Development environment enhancements

## Testing Patterns

### Component Testing
- **Location**: `spec/components/`
- **Examples**: ViewComponent testing with RSpec

### Controller Testing
- **Location**: `spec/controllers/`
- **Demonstrates**: Rails controller testing patterns

### System Testing
- **Location**: `spec/system/`
- **Examples**: End-to-end testing with Capybara

## Generator Examples

### Custom Generators
- **Location**: `lib/generators/`
- **Documentation**: `docs/generators.md`
- **Examples**:
  - UI Component generator
  - Service object generator
  - AI model generator

## Styling and CSS Patterns

### DaisyUI Integration
- **Location**: `app/assets/stylesheets/`
- **Examples**: Custom CSS with DaisyUI utilities

### Theme System
- **Documentation**: `docs/theme-system.md`
- **Implementation**: Theme switching and customization

### Responsive Design
- **Examples**: Throughout view files
- **Patterns**: Mobile-first responsive implementations

## JavaScript and Stimulus Examples

### Stimulus Controllers
- **Location**: `app/javascript/controllers/`
- **Examples**:
  - Theme switching
  - Real-time updates
  - Component interactions
  - Form enhancements

### ActionCable Integration
- **Location**: `app/javascript/channels/`
- **Examples**: Real-time communication patterns

## Documentation Structure

### Component Documentation
- **Location**: `docs/components/`
- **Purpose**: Detailed component usage and examples

### Feature Documentation
- **Location**: `docs/`
- **Examples**: Feature-specific implementation guides

## Best Practices and Patterns

### Security Patterns
- Authentication and authorization examples
- CSRF protection implementation
- Secure file handling

### Performance Patterns
- Background job usage
- Caching strategies
- Database optimization

### Error Handling
- Graceful error handling patterns
- User-friendly error messages
- Logging and monitoring

## Getting Started for AI Assistants

1. **Start with Lookbook**: Visit the component library for visual examples (development only)
2. **Review the Welcome Page**: See comprehensive DaisyUI usage (admin access required)
3. **Examine AppProject**: Study the complete feature implementation
4. **Check Service Objects**: Understand business logic patterns
5. **Look at Generators**: See code generation patterns
6. **Review Tests**: Understand testing approaches

**Note**: The welcome, themes, and icons pages require admin user privileges to access.

## Key Files for AI Reference

### Primary Examples
- `app/views/pages/welcome.html.erb` - DaisyUI showcase
- `app/controllers/app_projects_controller.rb` - Complex controller
- `app/components/ui/` - Component implementations
- `app/services/llm/` - Service object patterns
- `spec/` - Testing examples

### Configuration References
- `CLAUDE.md` - Project-specific instructions
- `docs/generators.md` - Generator usage
- `docs/theme-system.md` - Styling system
- `docs/components/README.md` - Component library

This guide should help AI assistants quickly locate relevant examples and understand the codebase patterns when implementing new features or making modifications.