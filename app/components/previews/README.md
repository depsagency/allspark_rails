# Component Previews

This directory contains Lookbook preview files for all UI components in the application.

## Available Previews

- **Button Component** - Multiple variants, sizes, and states
- **Card Component** - Flexible container layouts
- **Notification Component** - Real-time notification displays

## Development

To access the component library:
1. Start the Rails server: `rails server`
2. Visit http://localhost:3000/lookbook

## Adding New Previews

Create preview files following this pattern:
```ruby
# app/components/previews/ui/my_component_preview.rb

module Ui
  # @label My Component
  class MyComponentPreview < Lookbook::Preview
    # @label Default Example
    def default
      render Ui::MyComponent.new(text: "Hello World")
    end
  end
end
```