---
title: Component Library Documentation
---

# Component Library Documentation

This Rails application includes a comprehensive component library built with ViewComponent and styled with DaisyUI. All components are documented and can be previewed using Lookbook.

## Accessing the Component Library

In development mode, you can access the component library at:
- **Lookbook Interface**: http://localhost:3000/lookbook

## Component Structure

All components are located in the `app/components/` directory and follow this structure:

```
app/components/
├── base_component.rb          # Base class for all components
├── ui/                        # UI components
│   ├── button_component.rb
│   ├── card_component.rb
│   ├── notification_component.rb
│   ├── navbar_component.rb
│   ├── modal_component.rb
│   ├── form_component.rb
│   ├── table_component.rb
│   ├── badge_component.rb
│   ├── avatar_component.rb
│   ├── progress_component.rb
│   ├── alert_component.rb
│   ├── breadcrumb_component.rb
│   ├── pagination_component.rb
│   └── tabs_component.rb
└── previews/                  # Lookbook preview files
    └── ui/
        ├── button_component_preview.rb
        ├── card_component_preview.rb
        └── notification_component_preview.rb
```

## Available Components

### Core UI Components

1. **Button Component** (`Ui::ButtonComponent`)
   - Multiple variants: primary, secondary, accent, ghost, link, outline
   - Different sizes: xs, sm, md, lg
   - States: disabled, loading
   - Icon support

2. **Card Component** (`Ui::CardComponent`)
   - Flexible container component
   - Compact and bordered variants
   - Title and action support

3. **Alert Component** (`Ui::AlertComponent`)
   - Types: info, success, warning, error
   - Dismissible and persistent variants
   - Real-time integration with ActionCable

4. **Navbar Component** (`Ui::NavbarComponent`)
   - Responsive navigation
   - Theme switching support
   - User menu integration

5. **Modal Component** (`Ui::ModalComponent`)
   - Various sizes and configurations
   - Form integration
   - Backdrop and keyboard handling

6. **Form Component** (`Ui::FormComponent`)
   - DaisyUI form styling
   - Validation error display
   - Integration with Simple Form

7. **Table Component** (`Ui::TableComponent`)
   - Responsive tables
   - Sorting and pagination support
   - Action columns

8. **Badge Component** (`Ui::BadgeComponent`)
   - Status indicators
   - Color variants
   - Size options

9. **Avatar Component** (`Ui::AvatarComponent`)
   - User profile images
   - Placeholder generation
   - Size variants

10. **Progress Component** (`Ui::ProgressComponent`)
    - Progress bars and radial progress
    - Real-time updates
    - Color variants

## Design Principles

### DaisyUI Integration
- All components use DaisyUI CSS classes for consistent styling
- Theme-aware components that adapt to the selected theme
- Responsive design by default

### Accessibility
- Semantic HTML structure
- ARIA labels and attributes
- Keyboard navigation support
- Screen reader compatibility

### Performance
- ViewComponent architecture for efficient rendering
- Stimulus controllers for interactive behavior
- Minimal JavaScript footprint

## Theme System

The application supports 30+ DaisyUI themes:
- **Light themes**: light, cupcake, bumblebee, emerald, corporate, garden, lofi, pastel, fantasy, wireframe
- **Dark themes**: dark, synthwave, retro, cyberpunk, valentine, halloween, forest, aqua, luxury, dracula, business, acid, lemonade, night, coffee, winter, dim, nord, sunset, autumn, cmyk

Users can switch themes using the theme selector in the navbar.

## Real-time Features

Many components integrate with ActionCable for real-time updates:
- **Notifications**: Real-time notification delivery
- **Progress**: Live progress updates
- **Presence**: User online/offline status
- **Live Updates**: Real-time content updates

## Testing

All components include comprehensive tests:
- **Unit tests**: Component rendering and behavior
- **System tests**: Integration with the full application
- **Preview tests**: Lookbook preview functionality

## Usage Examples

### Basic Button
```erb
<%= render Ui::ButtonComponent.new(
  text: "Save Changes",
  variant: :primary,
  size: :md
) %>
```

### Card with Content
```erb
<%= render Ui::CardComponent.new(title: "User Profile", bordered: true) do %>
  <p>User profile content goes here...</p>
<% end %>
```

### Alert
```erb
<%= render Ui::AlertComponent.new(
  type: :success,
  title: "Success!",
  dismissible: true
) do %>
  Your changes have been saved.
<% end %>
```

## Development Guidelines

### Creating New Components

1. Create the component class in `app/components/ui/`
2. Inherit from `BaseComponent`
3. Use DaisyUI classes for styling
4. Add proper documentation comments
5. Create a preview file in `app/components/previews/ui/`
6. Write comprehensive tests in `spec/components/ui/`

### Preview Guidelines

- Use `@label` and `@display_name` annotations
- Include parameter controls with `@param`
- Show multiple variants and states
- Provide realistic sample data
- Include accessibility examples

### Styling Guidelines

- Use DaisyUI utility classes
- Follow semantic HTML structure
- Ensure responsive design
- Test with multiple themes
- Validate accessibility

## Resources

- [ViewComponent Documentation](https://viewcomponent.org/)
- [DaisyUI Documentation](https://daisyui.com/)
- [Lookbook Documentation](https://lookbook.build/)
- [Stimulus Documentation](https://stimulus.hotwired.dev/)
- [ActionCable Documentation](https://guides.rubyonrails.org/action_cable_overview.html)