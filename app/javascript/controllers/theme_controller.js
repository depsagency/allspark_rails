
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["toggle", "selector", "indicator"]
  static values = { 
    current: String,
    default: String,
    storageKey: String
  }

  connect() {
    console.log("Theme controller connected")
    this.initializeTheme()
  }

  // Initialize theme from localStorage or default to light
  initializeTheme() {
    const savedTheme = this.getSavedTheme()
    // Always default to 'light' if no theme is saved
    const theme = savedTheme || this.defaultValue || 'light'
    this.setTheme(theme)
  }

  // Get theme from localStorage
  getSavedTheme() {
    try {
      return localStorage.getItem(this.storageKeyValue || "daisyui-theme")
    } catch (error) {
      console.warn("Could not access localStorage for theme:", error)
      return null
    }
  }

  // Save theme to localStorage
  saveTheme(theme) {
    try {
      localStorage.setItem(this.storageKeyValue || "daisyui-theme", theme)
    } catch (error) {
      console.warn("Could not save theme to localStorage:", error)
    }
  }

  // Set theme on document
  setTheme(theme) {
    this.currentValue = theme
    document.documentElement.setAttribute("data-theme", theme)
    this.saveTheme(theme)
    this.updateControls(theme)
    this.dispatch("changed", { detail: { theme } })
  }

  // Update theme controls to reflect current theme
  updateControls(theme) {
    // Update theme selector dropdown
    this.selectorTargets.forEach(selector => {
      if (selector.tagName === "SELECT") {
        selector.value = theme
      } else {
        // Handle dropdown items
        selector.querySelectorAll("[data-theme-option]").forEach(item => {
          item.classList.toggle("active", item.dataset.themeOption === theme)
        })
      }
    })

    // Update theme toggle buttons
    this.toggleTargets.forEach(toggle => {
      const isActive = toggle.dataset.themeValue === theme
      toggle.classList.toggle("btn-active", isActive)
      toggle.setAttribute("aria-pressed", isActive)
    })

    // Update theme indicators
    this.indicatorTargets.forEach(indicator => {
      indicator.textContent = this.getThemeDisplayName(theme)
    })
  }

  // Action: Toggle between light and dark
  toggle() {
    const currentTheme = this.currentValue || "light"
    const newTheme = currentTheme === "light" ? "dark" : "light"
    this.setTheme(newTheme)
  }

  // Action: Set specific theme (legacy method name for compatibility)
  switch(event) {
    this.selectTheme(event)
  }

  // Action: Set specific theme
  selectTheme(event) {
    const theme = event.target.dataset.themeValue || 
                  event.target.dataset.themeOption ||
                  event.target.value
    
    if (theme && theme !== this.currentValue) {
      this.setTheme(theme)
    }
  }

  // Action: Cycle through popular themes
  cycle() {
    const popularThemes = ["light", "dark", "cupcake", "synthwave", "retro", "cyberpunk", "emerald", "corporate"]
    const currentIndex = popularThemes.indexOf(this.currentValue)
    const nextIndex = (currentIndex + 1) % popularThemes.length
    this.setTheme(popularThemes[nextIndex])
  }

  // Action: Reset to default theme
  reset() {
    this.setTheme(this.defaultValue || this.systemDefault)
  }

  // Action: Use system theme
  useSystem() {
    this.setTheme(this.systemDefault)
    this.watchSystemTheme()
  }

  // Watch for system theme changes
  watchSystemTheme() {
    if (typeof window !== "undefined" && window.matchMedia) {
      const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
      const handler = (e) => {
        this.setTheme(e.matches ? "dark" : "light")
      }
      
      // Remove any existing listeners
      if (this.systemThemeHandler) {
        mediaQuery.removeEventListener("change", this.systemThemeHandler)
      }
      
      // Add new listener
      this.systemThemeHandler = handler
      mediaQuery.addEventListener("change", handler)
    }
  }

  // Get system default theme - always return light to ensure consistent default
  get systemDefault() {
    // Always return light theme as the default, ignoring system preferences
    return "light"
  }

  // Legacy getter for compatibility
  get theme() {
    return this.currentValue || this.getSavedTheme() || this.systemDefault
  }

  // Legacy setter for compatibility
  set theme(value) {
    this.setTheme(value)
  }

  // Apply theme (legacy method for compatibility)
  apply() {
    this.setTheme(this.theme)
  }

  // Get display name for theme
  getThemeDisplayName(theme) {
    const displayNames = {
      light: "Light",
      dark: "Dark",
      cupcake: "Cupcake",
      bumblebee: "Bumblebee",
      emerald: "Emerald",
      corporate: "Corporate",
      synthwave: "Synthwave",
      retro: "Retro",
      cyberpunk: "Cyberpunk",
      valentine: "Valentine",
      halloween: "Halloween",
      garden: "Garden",
      forest: "Forest",
      aqua: "Aqua",
      lofi: "Lo-Fi",
      pastel: "Pastel",
      fantasy: "Fantasy",
      wireframe: "Wireframe",
      black: "Black",
      luxury: "Luxury",
      dracula: "Dracula",
      cmyk: "CMYK",
      autumn: "Autumn",
      business: "Business",
      acid: "Acid",
      lemonade: "Lemonade",
      night: "Night",
      coffee: "Coffee",
      winter: "Winter",
      dim: "Dim",
      nord: "Nord",
      sunset: "Sunset"
    }
    return displayNames[theme] || theme.charAt(0).toUpperCase() + theme.slice(1)
  }

  // Get theme category
  getThemeCategory(theme) {
    const lightThemes = ["light", "cupcake", "bumblebee", "emerald", "corporate", "garden", "lofi", "pastel", "fantasy", "wireframe", "cmyk", "autumn", "business", "acid", "lemonade", "winter"]
    const darkThemes = ["dark", "synthwave", "retro", "cyberpunk", "valentine", "halloween", "forest", "aqua", "black", "luxury", "dracula", "night", "coffee", "dim", "nord", "sunset"]
    
    if (lightThemes.includes(theme)) return "light"
    if (darkThemes.includes(theme)) return "dark"
    return "neutral"
  }

  // Check if current theme is dark
  isDarkTheme() {
    return this.getThemeCategory(this.currentValue) === "dark"
  }

  // Cleanup when controller disconnects
  disconnect() {
    if (this.systemThemeHandler && typeof window !== "undefined" && window.matchMedia) {
      const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
      mediaQuery.removeEventListener("change", this.systemThemeHandler)
    }
  }
}
