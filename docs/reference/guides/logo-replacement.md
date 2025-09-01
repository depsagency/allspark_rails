# Logo Replacement Guide

This guide explains how to replace the default DaisyUI logo in the header with your own custom logo.

## Logo Specifications

### Recommended Dimensions
- **Width**: 120-150 pixels
- **Height**: 32-40 pixels
- **Aspect ratio**: 3:1 to 4:1 (landscape orientation)
- **Format**: SVG (preferred) or PNG with transparency

### Design Considerations
- **Readability**: Ensure text is readable at small sizes (32-40px height)
- **Contrast**: Use good contrast for both light and dark themes
- **Mobile responsiveness**: Logo should work well on mobile devices
- **File size**: Keep under 50KB for optimal loading

### Current Header Constraints
- Header height: 64px (`h-16` in Tailwind)
- Available vertical space: ~32-40px (accounting for padding)
- Logo sits alongside navigation elements
- Text size changes from `text-lg` to `text-2xl` on larger screens

## File Placement

Place your logo file in the following location:
```
app/assets/images/logo.svg
```
or
```
app/assets/images/logo.png
```

## Implementation

### Current Code Structure
The logo is located in `/app/views/layouts/_header.html.erb` at approximately line 13:

```erb
<svg width="32" height="32" viewBox="0 0 415 415" xmlns="http://www.w3.org/2000/svg">
  <!-- SVG content -->
</svg>
<div class="font-title inline-flex text-lg md:text-2xl">
  <span class="lowercase">daisy</span>
  <span class="uppercase text-[#1AD1A5]">UI</span>
</div>
```

### Replacement Code

Replace the entire SVG and text block with your logo:

#### For SVG logos:
```erb
<%= image_tag "logo.svg", 
    alt: "Your Company Name", 
    class: "h-8 w-auto",
    style: "max-width: 150px;" %>
```

#### For PNG logos:
```erb
<%= image_tag "logo.png", 
    alt: "Your Company Name", 
    class: "h-8 w-auto",
    style: "max-width: 150px;" %>
```

### Complete Header Section Replacement

Find this section in `/app/views/layouts/_header.html.erb`:

```erb
<a href="/" aria-current="page" aria-label="Homepage" class="flex-0 btn btn-ghost px-2">
  <!-- Replace everything between these tags -->
  <svg width="32" height="32" viewBox="0 0 415 415" xmlns="http://www.w3.org/2000/svg">
    <rect x="82.5" y="290" width="250" height="125" rx="62.5" fill="#1AD1A5"></rect>
    <circle cx="207.5" cy="135" r="130" fill="black" fill-opacity=".3"></circle>
    <circle cx="207.5" cy="135" r="125" fill="white"></circle><circle cx="207.5" cy="135" r="56" fill="#FF9903"></circle>
  </svg>
  <div class="font-title inline-flex text-lg md:text-2xl">
    <span class="lowercase">daisy</span>
    <span class="uppercase text-[#1AD1A5]">UI</span>
  </div>
  <!-- End replacement section -->
</a>
```

Replace with:

```erb
<a href="/" aria-current="page" aria-label="Homepage" class="flex-0 btn btn-ghost px-2">
  <%= image_tag "logo.svg", 
      alt: "Your Company Name", 
      class: "h-8 w-auto",
      style: "max-width: 150px;" %>
</a>
```

## Logo Creation Tips

### Using AI Tools
You can use AI tools like:
- **DALL-E**: "Create a professional logo for [company name] with text, 150x40 pixels, transparent background"
- **Midjourney**: "clean modern logo design, company name text, horizontal layout, transparent background --ar 4:1"
- **Canva**: Use their logo templates and export as SVG or PNG

### Design Tools
- **Figma**: Free, web-based design tool
- **Adobe Illustrator**: Professional vector graphics
- **Inkscape**: Free, open-source vector graphics

### Logo Requirements
1. **Include company/product name** in the logo
2. **Use readable fonts** at small sizes
3. **Transparent background** (PNG/SVG)
4. **Vector format preferred** (SVG) for crisp scaling
5. **Consistent with brand colors** and theme

## Testing Your Logo

After implementing your logo:

1. **Test responsiveness**: Check on mobile and desktop
2. **Test themes**: Verify it works with light and dark themes
3. **Check navigation**: Ensure the logo is still clickable and leads to homepage
4. **Validate sizing**: Logo should not overflow or appear too small

## Sidebar Logo

Don't forget to also update the sidebar logo in `/app/views/layouts/_sidebar.html.erb` around line 7-17 to match your header logo for consistency.

## Troubleshooting

### Common Issues
- **Logo too large**: Reduce width or adjust `max-width` style
- **Logo too small**: Increase height class from `h-8` to `h-10`
- **Poor contrast**: Ensure logo works on both light/dark backgrounds
- **Blurry on high-DPI**: Use SVG format or provide 2x PNG version

### File Path Issues
- Ensure logo file is in `app/assets/images/`
- Restart Rails server after adding new assets
- Check Rails asset pipeline is working: `rails assets:precompile`