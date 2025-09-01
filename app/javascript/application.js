// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import "./channels"

// Import jQuery and make it global first
import $ from 'jquery'
window.$ = window.jQuery = $

// jQuery Terminal loaded via CDN

// Import our terminal implementation
import "./terminal"

// Import DevTools monitoring (only loads in development)
import "./devtools_monitor"
