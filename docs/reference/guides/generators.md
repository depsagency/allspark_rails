# Component Generators

This Rails application includes custom generators for creating ViewComponents with DaisyUI styling, Lookbook previews, and comprehensive testing.

## Available Generators

### UI Component Generator

Generate a complete ViewComponent with all necessary files:

```bash
rails generate ui_component COMPONENT_NAME [options]
```

#### Options

- `--namespace=NAMESPACE` - Component namespace (default: UI)
- `--variants=VARIANT1,VARIANT2` - Component variants (default: primary,secondary)
- `--with-stimulus` - Include Stimulus controller
- `--skip-preview` - Skip Lookbook preview generation
- `--skip-test` - Skip test file generation

#### Examples

```bash
# Basic component
rails generate ui_component alert

# Component with variants
rails generate ui_component badge --variants=success,warning,error

# Component with Stimulus controller
rails generate ui_component modal --with-stimulus

# Custom namespace
rails generate ui_component sidebar --namespace=Layout
```

#### Generated Files

For a component named `badge` with variants `success,warning,error`:

1. **Component Class**: `app/components/ui/badge_component.rb`
   - Dry::Initializer integration
   - Variant and size options
   - DaisyUI CSS class helpers
   - Data attributes support

2. **Template**: `app/components/ui/badge_component.html.erb`
   - Semantic HTML structure
   - CSS class binding
   - Content slot support

3. **Preview**: `app/components/previews/ui/badge_component_preview.rb`
   - Multiple examples showing variants and states
   - Interactive controls for Lookbook
   - Documentation annotations

4. **Test**: `spec/components/ui/badge_component_spec.rb`
   - Comprehensive component testing
   - Variant and state validation
   - Accessibility checks

5. **Stimulus Controller** (optional): `app/javascript/controllers/badge_component_controller.js`
   - Interactive behavior
   - Value and target definitions
   - Event handling setup

## Usage in Views

After generating a component, use it in your views:

```erb
<%= render UI::BadgeComponent.new(
  text: "Success",
  variant: :success,
  size: :sm
) %>
```

## Component Structure

All generated components follow this structure:

### Base Class Integration
- Inherit from `BaseComponent`
- Use `Dry::Initializer` for options
- Include DaisyUI CSS helpers

### Variants System
- Predefined variant options
- CSS class mapping
- Theme-aware styling

### Size System
- Consistent sizing: xs, sm, md, lg
- Responsive design support

### State Management
- Disabled state support
- CSS class toggles
- Accessibility attributes

## Styling Guidelines

Generated components use DaisyUI classes:

```ruby
def base_classes
  "badge"  # Base DaisyUI class
end

def variant_classes
  case variant
  when :success
    "badge--success"
  when :warning
    "badge--warning"
  when :error
    "badge--error"
  end
end
```

## Testing Strategy

Generated tests cover:
- Component rendering
- Variant styling
- Size variations
- State handling
- Content options
- Data attributes
- Accessibility features

## Stimulus Integration

When using `--with-stimulus`, components include:
- Controller connection
- Value definitions
- Target elements
- Action methods
- State management

## Lookbook Previews

Generated previews include:
- Default example
- All variants showcase
- All sizes demonstration
- State examples
- Interactive demos (with Stimulus)
- Custom styling examples

## Customization

### Adding New Variants

1. Update the component class enum
2. Add variant CSS classes
3. Update the preview examples
4. Add test cases

### Adding Custom Options

1. Add option to component class
2. Use option in template
3. Update preview controls
4. Add test coverage

## Best Practices

1. **Consistent Naming**: Use descriptive component names
2. **DaisyUI Integration**: Leverage existing DaisyUI classes
3. **Accessibility**: Include proper ARIA attributes
4. **Testing**: Test all variants and states
5. **Documentation**: Use Lookbook previews for examples
6. **Performance**: Keep components lightweight

## Examples

### Simple Alert Component

```bash
rails generate ui_component alert --variants=info,success,warning,error
```

Usage:
```erb
<%= render UI::AlertComponent.new(
  text: "Operation successful!",
  variant: :success
) %>
```

### Interactive Modal Component

```bash
rails generate ui_component modal --with-stimulus --variants=small,medium,large
```

Usage:
```erb
<%= render UI::ModalComponent.new(
  title: "Confirm Action",
  variant: :medium
) do %>
  <p>Are you sure you want to continue?</p>
<% end %>
```

### Custom Layout Component

```bash
rails generate ui_component sidebar --namespace=Layout --variants=collapsed,expanded
```

Usage:
```erb
<%= render Layout::SidebarComponent.new(
  variant: :expanded
) do %>
  <!-- Navigation content -->
<% end %>
```