# UI Component Patterns

This guide documents the patterns and best practices for building UI components in this Rails application using ViewComponent and DaisyUI.

## Component Architecture

### Base Component Pattern
All components inherit from `BaseComponent` which provides common functionality:

```ruby
# app/components/base_component.rb
class BaseComponent < ViewComponent::Base
  include ApplicationHelper
  
  def initialize(**options)
    @options = options
    @class_names = options.delete(:class) || options.delete(:class_names)
    @data = options.delete(:data) || {}
  end
end
```

### Creating New Components
```ruby
# app/components/ui/alert_component.rb
class UI::AlertComponent < BaseComponent
  VARIANTS = %i[info success warning error].freeze
  
  def initialize(text: nil, variant: :info, dismissible: false, **options)
    @text = text
    @variant = variant
    @dismissible = dismissible
    super(**options)
  end
  
  private
  
  def variant_classes
    {
      info: "alert-info",
      success: "alert-success",
      warning: "alert-warning", 
      error: "alert-error"
    }[@variant]
  end
end
```

## Common UI Patterns

### Forms with DaisyUI
Always use Simple Form with DaisyUI styling for consistency:

```erb
<%= simple_form_for @model, html: { class: "space-y-4" } do |f| %>
  <div class="form-control">
    <%= f.input :name, 
                label_html: { class: "label" },
                input_html: { class: "input input-bordered" },
                wrapper_html: { class: "w-full" } %>
  </div>
  
  <div class="form-control">
    <%= f.input :description,
                as: :text,
                input_html: { class: "textarea textarea-bordered", rows: 4 } %>
  </div>
  
  <div class="form-control">
    <%= f.input :category,
                collection: categories,
                input_html: { class: "select select-bordered" } %>
  </div>
  
  <div class="form-control">
    <%= f.input :active,
                as: :boolean,
                input_html: { class: "checkbox checkbox-primary" } %>
  </div>
  
  <%= f.button :submit, class: "btn btn-primary" %>
<% end %>
```

### Card Layouts
Use the card component for content sections:

```erb
<%= render UI::CardComponent.new(title: "User Profile", bordered: true) do %>
  <div class="space-y-4">
    <!-- Card content -->
  </div>
<% end %>

<!-- With actions -->
<%= render UI::CardComponent.new do |card| %>
  <% card.with_title do %>
    <h2 class="card-title">Settings</h2>
  <% end %>
  
  <% card.with_body do %>
    <!-- Main content -->
  <% end %>
  
  <% card.with_actions do %>
    <button class="btn btn-primary">Save</button>
    <button class="btn btn-ghost">Cancel</button>
  <% end %>
<% end %>
```

### Button Patterns
Consistent button usage across the application:

```erb
<!-- Primary action -->
<%= render UI::ButtonComponent.new(
  text: "Save Changes",
  variant: :primary,
  size: :md,
  icon: "check"
) %>

<!-- Secondary action -->
<%= render UI::ButtonComponent.new(
  text: "Cancel",
  variant: :ghost,
  size: :md
) %>

<!-- Destructive action -->
<%= render UI::ButtonComponent.new(
  text: "Delete",
  variant: :error,
  size: :sm,
  icon: "trash",
  data: { 
    confirm: "Are you sure?",
    turbo_method: :delete
  }
) %>

<!-- Loading state -->
<%= render UI::ButtonComponent.new(
  text: "Processing...",
  variant: :primary,
  loading: true,
  disabled: true
) %>
```

### Modal Dialogs
Use modals for focused interactions:

```erb
<!-- Basic modal -->
<%= render UI::ModalComponent.new(id: "user-modal") do |modal| %>
  <% modal.with_header do %>
    <h3 class="font-bold text-lg">Edit User</h3>
  <% end %>
  
  <% modal.with_body do %>
    <%= render "form", user: @user %>
  <% end %>
  
  <% modal.with_footer do %>
    <button class="btn btn-primary">Save</button>
    <button class="btn btn-ghost" data-action="click->modal#close">Cancel</button>
  <% end %>
<% end %>

<!-- Trigger -->
<button class="btn" onclick="user-modal.showModal()">Edit</button>
```

### Alert Messages
Display feedback and notifications:

```erb
<!-- Success message -->
<%= render UI::AlertComponent.new(
  variant: :success,
  dismissible: true
) do %>
  <span>Your changes have been saved successfully!</span>
<% end %>

<!-- Error with details -->
<%= render UI::AlertComponent.new(
  variant: :error,
  title: "Error occurred"
) do %>
  <ul class="list-disc list-inside">
    <% @model.errors.full_messages.each do |message| %>
      <li><%= message %></li>
    <% end %>
  </ul>
<% end %>
```

### Data Tables
For displaying tabular data:

```erb
<%= render UI::DataTableComponent.new(
  items: @users,
  columns: [
    { key: :name, label: "Name", sortable: true },
    { key: :email, label: "Email" },
    { key: :role, label: "Role", badge: true },
    { key: :created_at, label: "Joined", format: :date }
  ],
  actions: true
) do |table| %>
  <% table.with_action do |user| %>
    <%= link_to "Edit", edit_user_path(user), class: "btn btn-sm btn-ghost" %>
  <% end %>
<% end %>
```

### Navigation Components
Consistent navigation patterns:

```erb
<!-- Navbar -->
<%= render UI::Navigation::NavbarComponent.new(
  brand: "My App",
  theme_switcher: true,
  user_menu: current_user
) do |nav| %>
  <% nav.with_nav_item(href: root_path, active: current_page?(root_path)) do %>
    Home
  <% end %>
  <% nav.with_nav_item(href: projects_path) do %>
    Projects
  <% end %>
<% end %>

<!-- Breadcrumbs -->
<div class="breadcrumbs text-sm">
  <ul>
    <li><%= link_to "Home", root_path %></li>
    <li><%= link_to "Users", users_path %></li>
    <li>Edit Profile</li>
  </ul>
</div>
```

## Responsive Design Patterns

### Mobile-First Grid Layouts
```erb
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <% @items.each do |item| %>
    <div class="card bg-base-100 shadow-xl">
      <!-- Card content -->
    </div>
  <% end %>
</div>
```

### Responsive Utilities
```erb
<!-- Show/hide based on screen size -->
<div class="hidden lg:block">Desktop only content</div>
<div class="lg:hidden">Mobile only content</div>

<!-- Responsive spacing -->
<div class="p-4 md:p-6 lg:p-8">
  <!-- Content with responsive padding -->
</div>
```

## Loading States

### Skeleton Loaders
```erb
<div class="animate-pulse">
  <div class="h-4 bg-base-300 rounded w-3/4 mb-2"></div>
  <div class="h-4 bg-base-300 rounded w-1/2"></div>
</div>
```

### Progress Indicators
```erb
<!-- Linear progress -->
<%= render UI::ProgressComponent.new(
  value: @progress,
  max: 100,
  variant: :primary
) %>

<!-- Radial progress -->
<div class="radial-progress" style="--value:<%= @percentage %>;">
  <%= @percentage %>%
</div>
```

## Empty States

```erb
<div class="hero min-h-[400px] bg-base-200 rounded-lg">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <%= render "icons/inbox", class: "w-16 h-16 mx-auto mb-4 text-base-content/50" %>
      <h3 class="text-lg font-bold">No projects yet</h3>
      <p class="py-4">Get started by creating your first project.</p>
      <%= link_to "Create Project", new_project_path, class: "btn btn-primary" %>
    </div>
  </div>
</div>
```

## Form Validation Feedback

```erb
<!-- Field with error -->
<div class="form-control">
  <%= f.input :email,
              input_html: { 
                class: "input input-bordered #{'input-error' if @user.errors[:email].any?}" 
              } %>
  <% if @user.errors[:email].any? %>
    <label class="label">
      <span class="label-text-alt text-error">
        <%= @user.errors[:email].first %>
      </span>
    </label>
  <% end %>
</div>
```

## Interactive Components with Stimulus

### Dropdown Menu
```erb
<div data-controller="dropdown" class="dropdown">
  <label tabindex="0" class="btn btn-ghost btn-sm">
    Options
    <%= render "icons/chevron-down", class: "w-4 h-4" %>
  </label>
  <ul tabindex="0" 
      class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52"
      data-dropdown-target="menu">
    <li><a>Edit</a></li>
    <li><a>Duplicate</a></li>
    <li><a class="text-error">Delete</a></li>
  </ul>
</div>
```

### Toggle Switch
```erb
<div class="form-control">
  <label class="label cursor-pointer">
    <span class="label-text">Enable notifications</span>
    <input type="checkbox" 
           class="toggle toggle-primary"
           data-controller="toggle"
           data-action="change->toggle#update">
  </label>
</div>
```

## Accessibility Patterns

### ARIA Labels
```erb
<button class="btn btn-circle" aria-label="Close dialog">
  <%= render "icons/x-mark", class: "w-4 h-4" %>
</button>
```

### Screen Reader Text
```erb
<span class="sr-only">Loading...</span>
<span aria-hidden="true" class="loading loading-spinner"></span>
```

## Best Practices

1. **Use ViewComponents** for reusable UI elements
2. **Follow DaisyUI conventions** for consistent styling
3. **Mobile-first responsive design** using Tailwind utilities
4. **Semantic HTML** for better accessibility
5. **Stimulus controllers** for interactivity
6. **Consistent spacing** using Tailwind's spacing scale
7. **Theme-aware colors** that work with all DaisyUI themes
8. **Loading states** for async operations
9. **Empty states** for better UX
10. **Error handling** with clear user feedback

## Component Testing

```ruby
# spec/components/ui/button_component_spec.rb
require "rails_helper"

RSpec.describe UI::ButtonComponent, type: :component do
  it "renders button with correct classes" do
    render_inline(described_class.new(
      text: "Click me",
      variant: :primary,
      size: :md
    ))
    
    expect(page).to have_css("button.btn.btn-primary.btn-md")
    expect(page).to have_text("Click me")
  end
end
```