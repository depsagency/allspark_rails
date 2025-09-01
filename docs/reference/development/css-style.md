# CSS Style Guide

This guide outlines the CSS and Tailwind CSS conventions used in the AllSpark project.

## Tailwind CSS First

We follow a utility-first approach using Tailwind CSS and DaisyUI components.

### Utility Classes Order
Follow a consistent order for utility classes:

```html
<!-- Good - Consistent order -->
<div class="
  relative flex items-center justify-between
  w-full max-w-4xl mx-auto px-4 py-6
  bg-white dark:bg-gray-800 
  border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm
  hover:shadow-md transition-shadow duration-200
">

<!-- Order: 
  1. Layout (position, display, flex)
  2. Spacing (width, padding, margin)
  3. Colors (background, text)
  4. Borders and Effects
  5. Interactions (hover, transitions)
-->
```

### Component Extraction
Extract repeated patterns into components:

```css
/* app/assets/stylesheets/components.css */
@layer components {
  /* Card component */
  .card-base {
    @apply bg-white dark:bg-gray-800 rounded-lg shadow-sm;
    @apply border border-gray-200 dark:border-gray-700;
  }

  .card-interactive {
    @apply card-base hover:shadow-md transition-shadow duration-200;
  }

  /* Button variants */
  .btn-primary {
    @apply btn btn-sm bg-primary text-primary-content hover:bg-primary-focus;
  }

  .btn-secondary {
    @apply btn btn-sm bg-secondary text-secondary-content hover:bg-secondary-focus;
  }

  /* Form elements */
  .form-input {
    @apply input input-bordered w-full;
  }

  .form-label {
    @apply label-text font-medium mb-1;
  }

  .form-error {
    @apply text-error text-sm mt-1;
  }
}
```

## DaisyUI Components

### Using DaisyUI Classes
Prefer DaisyUI components over custom styles:

```html
<!-- Good - Using DaisyUI components -->
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Project Name</h2>
    <p>Project description goes here.</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">View Details</button>
    </div>
  </div>
</div>

<!-- Bad - Recreating DaisyUI components -->
<div class="bg-white rounded-lg shadow-lg p-6">
  <h2 class="text-xl font-bold mb-2">Project Name</h2>
  <p class="mb-4">Project description goes here.</p>
  <div class="flex justify-end">
    <button class="px-4 py-2 bg-blue-500 text-white rounded">View Details</button>
  </div>
</div>
```

### Theme Variables
Use DaisyUI theme variables for consistency:

```css
/* Good - Using theme variables */
.custom-element {
  background-color: hsl(var(--b2));
  color: hsl(var(--bc));
  border-color: hsl(var(--b3));
}

/* Bad - Hardcoded colors */
.custom-element {
  background-color: #f3f4f6;
  color: #1f2937;
  border-color: #e5e7eb;
}
```

## Responsive Design

### Mobile-First Approach
Always design mobile-first:

```html
<!-- Good - Mobile-first -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <div class="p-4 md:p-6 lg:p-8">
    <h3 class="text-lg md:text-xl lg:text-2xl">Title</h3>
  </div>
</div>

<!-- Bad - Desktop-first -->
<div class="grid grid-cols-3 sm:grid-cols-1">
  <!-- Backwards approach -->
</div>
```

### Breakpoint Usage
Use Tailwind's responsive prefixes consistently:

```html
<!-- Standard breakpoints -->
<div class="
  w-full          /* Mobile: 0px+ */
  sm:w-4/5        /* Small: 640px+ */
  md:w-3/4        /* Medium: 768px+ */
  lg:w-2/3        /* Large: 1024px+ */
  xl:w-1/2        /* Extra large: 1280px+ */
  2xl:w-1/3       /* 2X large: 1536px+ */
">
```

## Custom CSS Guidelines

### When to Write Custom CSS
Only write custom CSS when:
1. Creating complex animations
2. Implementing unique design requirements
3. Working with third-party libraries

```css
/* app/assets/stylesheets/custom.css */

/* Complex animation example */
@keyframes slide-in-up {
  from {
    transform: translateY(100%);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}

.animate-slide-in-up {
  animation: slide-in-up 0.3s ease-out;
}

/* Third-party library overrides */
.trix-content {
  @apply prose prose-sm max-w-none;
  
  h1 { @apply text-2xl font-bold mt-6 mb-4; }
  h2 { @apply text-xl font-bold mt-5 mb-3; }
  h3 { @apply text-lg font-semibold mt-4 mb-2; }
  
  ul { @apply list-disc list-inside my-4; }
  ol { @apply list-decimal list-inside my-4; }
  
  blockquote {
    @apply border-l-4 border-gray-300 pl-4 my-4 italic;
  }
}
```

### CSS Architecture
Follow BEM-like naming for custom components:

```css
/* Component */
.notification {
  @apply fixed top-4 right-4 z-50;
}

/* Element */
.notification__message {
  @apply p-4 rounded-lg shadow-lg;
}

/* Modifier */
.notification__message--success {
  @apply bg-success text-success-content;
}

.notification__message--error {
  @apply bg-error text-error-content;
}
```

## Dark Mode Support

### Using Dark Mode Classes
Always provide dark mode variants:

```html
<!-- Good - Dark mode support -->
<div class="bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100">
  <h2 class="text-gray-800 dark:text-gray-200">Title</h2>
  <p class="text-gray-600 dark:text-gray-400">Description</p>
</div>

<!-- Using DaisyUI's theme-aware classes -->
<div class="bg-base-100 text-base-content">
  <h2 class="text-base-content">Title</h2>
  <p class="text-base-content/70">Description with reduced opacity</p>
</div>
```

### Custom Dark Mode Styles
```css
/* Custom dark mode handling */
@media (prefers-color-scheme: dark) {
  .custom-element {
    --shadow-color: rgba(0, 0, 0, 0.3);
  }
}

@media (prefers-color-scheme: light) {
  .custom-element {
    --shadow-color: rgba(0, 0, 0, 0.1);
  }
}

.custom-element {
  box-shadow: 0 4px 6px var(--shadow-color);
}
```

## Form Styling

### Consistent Form Elements
Use DaisyUI form classes:

```html
<!-- Standard form layout -->
<form class="space-y-4">
  <!-- Text input -->
  <div class="form-control">
    <label class="label">
      <span class="label-text">Email</span>
    </label>
    <input type="email" 
           class="input input-bordered" 
           placeholder="user@example.com">
    <label class="label">
      <span class="label-text-alt text-error">Email is required</span>
    </label>
  </div>

  <!-- Select -->
  <div class="form-control">
    <label class="label">
      <span class="label-text">Role</span>
    </label>
    <select class="select select-bordered">
      <option disabled selected>Select a role</option>
      <option>Admin</option>
      <option>User</option>
    </select>
  </div>

  <!-- Checkbox -->
  <div class="form-control">
    <label class="label cursor-pointer">
      <span class="label-text">Remember me</span>
      <input type="checkbox" class="checkbox checkbox-primary">
    </label>
  </div>

  <!-- Submit button -->
  <button type="submit" class="btn btn-primary">
    Submit
  </button>
</form>
```

## Animation and Transitions

### Performance-Conscious Animations
Use GPU-accelerated properties:

```css
/* Good - GPU accelerated */
.smooth-slide {
  transition: transform 0.3s ease, opacity 0.3s ease;
}

.smooth-slide:hover {
  transform: translateX(10px);
  opacity: 0.8;
}

/* Avoid animating expensive properties */
.bad-animation {
  transition: width 0.3s ease; /* Causes layout recalculation */
}
```

### Tailwind Transitions
Use Tailwind's transition utilities:

```html
<!-- Hover effects -->
<button class="
  bg-primary text-primary-content px-4 py-2 rounded
  transition-all duration-200 ease-in-out
  hover:bg-primary-focus hover:scale-105 hover:shadow-lg
">
  Click Me
</button>

<!-- Focus states -->
<input class="
  input input-bordered
  transition-colors duration-200
  focus:border-primary focus:ring-2 focus:ring-primary/20
">
```

## Accessibility Styling

### Focus Indicators
Always provide clear focus states:

```css
/* Custom focus styles */
.custom-button {
  @apply relative overflow-hidden;
}

.custom-button:focus {
  @apply outline-none;
}

.custom-button:focus-visible {
  @apply ring-2 ring-primary ring-offset-2;
}

/* Skip links */
.skip-link {
  @apply absolute left-0 top-0 bg-primary text-primary-content;
  @apply px-4 py-2 -translate-y-full focus:translate-y-0;
  @apply transition-transform duration-200;
}
```

### Color Contrast
Ensure sufficient contrast ratios:

```css
/* Good contrast examples */
.high-contrast {
  @apply bg-gray-900 text-white;      /* High contrast */
  @apply bg-blue-600 text-white;      /* WCAG AA compliant */
}

/* Check contrast with opacity */
.subtle-text {
  @apply text-base-content/70;  /* 70% opacity - verify contrast */
}
```

## File Organization

### CSS File Structure
```
app/assets/stylesheets/
├── application.tailwind.css    # Main entry point
├── components/                 # Component styles
│   ├── buttons.css
│   ├── cards.css
│   └── forms.css
├── utilities/                  # Custom utilities
│   ├── animations.css
│   └── typography.css
└── vendors/                    # Third-party overrides
    ├── trix.css
    └── flatpickr.css
```

### Import Order
```css
/* application.tailwind.css */
@import 'tailwindcss/base';
@import './vendors/trix';
@import './vendors/flatpickr';

@import 'tailwindcss/components';
@import './components/buttons';
@import './components/cards';
@import './components/forms';

@import 'tailwindcss/utilities';
@import './utilities/animations';
@import './utilities/typography';
```

## Performance Guidelines

### Purging Unused CSS
Configure PurgeCSS properly:

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/components/**/*.html.erb',
    './app/components/**/*.rb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
  ],
  // ...
}
```

### Critical CSS
Inline critical styles for above-the-fold content:

```erb
<!-- app/views/layouts/application.html.erb -->
<style>
  /* Critical inline styles */
  .hero-section {
    @apply min-h-screen flex items-center justify-center;
    @apply bg-gradient-to-br from-primary to-primary-focus;
  }
</style>
```

## Debugging Tips

### Using Browser DevTools
```css
/* Debug layout issues */
.debug * {
  outline: 1px solid red;
}

/* Debug spacing */
.debug-spacing {
  background-color: rgba(255, 0, 0, 0.1);
}

/* Temporary visibility */
.debug-hidden {
  opacity: 0.5 !important;
  border: 2px dashed red !important;
}
```

### Tailwind CSS IntelliSense
Configure your editor for better Tailwind support:
- Install Tailwind CSS IntelliSense extension
- Configure class sorting
- Enable autocomplete for custom classes