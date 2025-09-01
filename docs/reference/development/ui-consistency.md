# UI Consistency Guide

This guide ensures consistent user interface patterns across the AllSpark application.

## Design Principles

### 1. Clarity First
- Every UI element should have a clear purpose
- Use descriptive labels and helpful placeholders
- Provide immediate feedback for user actions

### 2. Consistency
- Use the same patterns throughout the application
- Maintain consistent spacing, colors, and typography
- Follow established interaction patterns

### 3. Accessibility
- All interactive elements must be keyboard accessible
- Maintain WCAG AA color contrast ratios
- Provide appropriate ARIA labels

### 4. Progressive Enhancement
- Core functionality works without JavaScript
- Enhanced experiences for modern browsers
- Graceful degradation for older browsers

## Layout Patterns

### Page Structure
```erb
<!-- Standard page layout -->
<div class="min-h-screen bg-base-200">
  <!-- Header -->
  <header class="navbar bg-base-100 shadow-sm">
    <%= render 'shared/navigation' %>
  </header>

  <!-- Main content -->
  <main class="container mx-auto px-4 py-8">
    <!-- Breadcrumbs -->
    <div class="breadcrumbs text-sm mb-4">
      <ul>
        <li><%= link_to 'Home', root_path %></li>
        <li><%= link_to 'Projects', projects_path %></li>
        <li class="font-semibold">Current Page</li>
      </ul>
    </div>

    <!-- Page header -->
    <div class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-bold">Page Title</h1>
      <div class="space-x-2">
        <%= link_to 'Secondary Action', '#', class: 'btn btn-ghost' %>
        <%= link_to 'Primary Action', '#', class: 'btn btn-primary' %>
      </div>
    </div>

    <!-- Content -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Main content -->
      <div class="lg:col-span-2">
        <%= yield %>
      </div>
      
      <!-- Sidebar -->
      <aside class="space-y-4">
        <%= render 'shared/sidebar' %>
      </aside>
    </div>
  </main>

  <!-- Footer -->
  <footer class="footer footer-center p-10 bg-base-300 text-base-content">
    <%= render 'shared/footer' %>
  </footer>
</div>
```

### Grid Systems
Use consistent grid layouts:

```erb
<!-- Card grid -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  <% @items.each do |item| %>
    <div class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow">
      <!-- Card content -->
    </div>
  <% end %>
</div>

<!-- Form grid -->
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="form-control">
    <!-- Form field -->
  </div>
  <div class="form-control">
    <!-- Form field -->
  </div>
</div>
```

## Component Patterns

### Cards
Standard card variations:

```erb
<!-- Basic card -->
<div class="card bg-base-100 shadow">
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Card content goes here.</p>
  </div>
</div>

<!-- Card with image -->
<div class="card bg-base-100 shadow">
  <figure>
    <%= image_tag 'placeholder.jpg', class: 'w-full h-48 object-cover' %>
  </figure>
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Card content goes here.</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary btn-sm">Action</button>
    </div>
  </div>
</div>

<!-- Horizontal card -->
<div class="card card-side bg-base-100 shadow">
  <figure class="w-1/3">
    <%= image_tag 'placeholder.jpg', class: 'h-full object-cover' %>
  </figure>
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Card content goes here.</p>
  </div>
</div>
```

### Tables
Consistent table styling:

```erb
<!-- Data table -->
<div class="overflow-x-auto">
  <table class="table table-zebra">
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>Role</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% @users.each do |user| %>
        <tr class="hover">
          <td><%= user.name %></td>
          <td><%= user.email %></td>
          <td>
            <span class="badge badge-primary"><%= user.role %></span>
          </td>
          <td>
            <div class="flex gap-2">
              <%= link_to 'Edit', edit_user_path(user), 
                  class: 'btn btn-ghost btn-xs' %>
              <%= link_to 'Delete', user_path(user), 
                  method: :delete,
                  data: { confirm: 'Are you sure?' },
                  class: 'btn btn-ghost btn-xs text-error' %>
            </div>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

### Modals
Standard modal pattern:

```erb
<!-- Modal trigger -->
<button class="btn" onclick="modal_1.showModal()">Open Modal</button>

<!-- Modal -->
<dialog id="modal_1" class="modal">
  <div class="modal-box">
    <h3 class="font-bold text-lg">Modal Title</h3>
    <p class="py-4">Modal content goes here.</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn btn-ghost">Cancel</button>
        <button class="btn btn-primary">Confirm</button>
      </form>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

## Typography

### Heading Hierarchy
```html
<h1 class="text-4xl font-bold mb-2">Page Title</h1>
<h2 class="text-2xl font-semibold mb-4">Section Title</h2>
<h3 class="text-xl font-medium mb-3">Subsection Title</h3>
<h4 class="text-lg font-medium mb-2">Card Title</h4>
<h5 class="text-base font-medium mb-1">Small Title</h5>
```

### Body Text
```html
<!-- Standard paragraph -->
<p class="text-base-content mb-4">
  Regular body text with proper spacing.
</p>

<!-- Secondary text -->
<p class="text-base-content/70 text-sm">
  Less important information or descriptions.
</p>

<!-- Help text -->
<p class="text-sm text-base-content/60 mt-1">
  Helper text for form fields or additional context.
</p>
```

## Color Usage

### Semantic Colors
Use DaisyUI's semantic color system:

```html
<!-- Primary actions -->
<button class="btn btn-primary">Save Changes</button>

<!-- Success states -->
<div class="alert alert-success">
  <span>Operation completed successfully!</span>
</div>

<!-- Warning states -->
<div class="alert alert-warning">
  <span>Please review before continuing.</span>
</div>

<!-- Error states -->
<div class="alert alert-error">
  <span>An error occurred. Please try again.</span>
</div>

<!-- Info states -->
<div class="alert alert-info">
  <span>New features are available.</span>
</div>
```

### Status Indicators
```html
<!-- Status badges -->
<span class="badge badge-success gap-2">
  <div class="w-2 h-2 rounded-full bg-current animate-pulse"></div>
  Active
</span>

<span class="badge badge-warning gap-2">
  <div class="w-2 h-2 rounded-full bg-current"></div>
  Pending
</span>

<span class="badge badge-error gap-2">
  <div class="w-2 h-2 rounded-full bg-current"></div>
  Inactive
</span>
```

## Form Patterns

### Form Layout
```erb
<%= form_with model: @user, class: 'space-y-6' do |f| %>
  <!-- Text input -->
  <div class="form-control">
    <%= f.label :name, class: 'label' do %>
      <span class="label-text">Name</span>
      <span class="label-text-alt text-error">*</span>
    <% end %>
    <%= f.text_field :name, 
        class: 'input input-bordered',
        placeholder: 'Enter your name' %>
    <% if @user.errors[:name].any? %>
      <label class="label">
        <span class="label-text-alt text-error">
          <%= @user.errors[:name].first %>
        </span>
      </label>
    <% end %>
  </div>

  <!-- Select dropdown -->
  <div class="form-control">
    <%= f.label :role, class: 'label' do %>
      <span class="label-text">Role</span>
    <% end %>
    <%= f.select :role, 
        options_for_select(User::ROLES),
        { prompt: 'Select a role' },
        class: 'select select-bordered' %>
  </div>

  <!-- Checkbox -->
  <div class="form-control">
    <label class="label cursor-pointer justify-start gap-4">
      <%= f.check_box :active, class: 'checkbox checkbox-primary' %>
      <span class="label-text">Active account</span>
    </label>
  </div>

  <!-- Form actions -->
  <div class="flex gap-2">
    <%= f.submit 'Save', class: 'btn btn-primary' %>
    <%= link_to 'Cancel', users_path, class: 'btn btn-ghost' %>
  </div>
<% end %>
```

## Loading States

### Skeleton Screens
```erb
<!-- Card skeleton -->
<div class="card bg-base-100 shadow animate-pulse">
  <div class="card-body">
    <div class="h-6 bg-base-300 rounded w-3/4 mb-4"></div>
    <div class="space-y-2">
      <div class="h-4 bg-base-300 rounded"></div>
      <div class="h-4 bg-base-300 rounded w-5/6"></div>
    </div>
  </div>
</div>

<!-- Table skeleton -->
<div class="animate-pulse">
  <div class="h-10 bg-base-300 rounded mb-2"></div>
  <div class="space-y-2">
    <div class="h-8 bg-base-200 rounded"></div>
    <div class="h-8 bg-base-200 rounded"></div>
    <div class="h-8 bg-base-200 rounded"></div>
  </div>
</div>
```

### Loading Spinners
```html
<!-- Button loading state -->
<button class="btn btn-primary">
  <span class="loading loading-spinner"></span>
  Saving...
</button>

<!-- Full page loader -->
<div class="fixed inset-0 bg-base-200/80 flex items-center justify-center z-50">
  <div class="flex flex-col items-center gap-4">
    <span class="loading loading-spinner loading-lg"></span>
    <p class="text-base-content/70">Loading...</p>
  </div>
</div>
```

## Empty States

### No Data
```erb
<div class="flex flex-col items-center justify-center py-12 text-center">
  <svg class="w-16 h-16 text-base-content/20 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
  </svg>
  <h3 class="text-lg font-medium mb-2">No projects yet</h3>
  <p class="text-base-content/70 mb-6 max-w-md">
    Create your first project to get started with AllSpark.
  </p>
  <%= link_to 'Create Project', new_project_path, class: 'btn btn-primary' %>
</div>
```

## Notifications

### Toast Notifications
```erb
<!-- Success toast -->
<div class="toast toast-end">
  <div class="alert alert-success">
    <span>Changes saved successfully!</span>
  </div>
</div>

<!-- Error toast -->
<div class="toast toast-end">
  <div class="alert alert-error">
    <span>Failed to save changes. Please try again.</span>
  </div>
</div>
```

## Mobile Responsiveness

### Navigation
```erb
<!-- Mobile menu -->
<div class="drawer drawer-end lg:hidden">
  <input id="mobile-menu" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Page content -->
    <label for="mobile-menu" class="btn btn-square btn-ghost drawer-button">
      <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
      </svg>
    </label>
  </div>
  <div class="drawer-side">
    <label for="mobile-menu" class="drawer-overlay"></label>
    <ul class="menu p-4 w-80 min-h-full bg-base-100">
      <!-- Menu items -->
    </ul>
  </div>
</div>
```

### Touch Targets
Ensure adequate touch target sizes:
```html
<!-- Good - 44x44px minimum touch target -->
<button class="btn btn-square btn-lg">
  <svg class="w-6 h-6"><!-- Icon --></svg>
</button>

<!-- Mobile-friendly spacing -->
<div class="space-y-4">
  <button class="btn btn-block">Option 1</button>
  <button class="btn btn-block">Option 2</button>
  <button class="btn btn-block">Option 3</button>
</div>
```