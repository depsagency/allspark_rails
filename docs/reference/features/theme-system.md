# Theme System

This Rails application includes a simple theme switcher that allows users to switch between 30+ beautiful DaisyUI themes with automatic persistence.

## Quick Start

Add a theme switcher to any view:

```erb
<%= render UI::ThemeSwitcherComponent.new %>
```

Add to your navbar:
```erb
<%= render UI::Navigation::NavbarComponent.new(theme_switcher: true) %>
```

## Variants

**Dropdown (default)** - Full theme selection:
```erb
<%= render UI::ThemeSwitcherComponent.new(variant: :dropdown) %>
```

**Toggle** - Simple light/dark toggle:
```erb
<%= render UI::ThemeSwitcherComponent.new(variant: :toggle) %>
```

## Popular Themes

- `light` - Clean light theme
- `dark` - Modern dark theme  
- `cupcake` - Soft pink theme
- `synthwave` - Retro neon theme
- `emerald` - Nature-inspired green
- `corporate` - Professional blue

[See all 30+ themes in DaisyUI documentation](https://daisyui.com/docs/themes/)

## Features

- **Automatic persistence** - Remembers user choice in localStorage
- **System theme detection** - Follows OS light/dark preference
- **Instant switching** - No page reload required
- **Mobile responsive** - Works on all screen sizes

## Advanced Usage

For detailed customization, events, and JavaScript API, see the [DaisyUI themes documentation](https://daisyui.com/docs/themes/).