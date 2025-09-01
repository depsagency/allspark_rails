import { Controller } from "@hotwired/stimulus"

// Navbar controller for navigation functionality
//
// Provides functionality for:
// - Mobile menu toggle
// - Theme switching
// - Search handling
// - User menu interactions
//
// Usage:
//   <div data-controller="navbar">
//     <button data-action="click->navbar#toggleMobileMenu">Menu</button>
//     <input data-action="search->navbar#search">
//   </div>
//
export default class extends Controller {
  static targets = ["mobileMenu", "searchInput"]
  static values = {
    searchDelay: { type: Number, default: 300 }
  }

  connect() {
    this.searchTimeout = null
    this.setupTheme()
    this.handleOutsideClicks()
  }

  disconnect() {
    this.clearSearchTimeout()
    this.removeOutsideClickListener()
  }

  // Toggle mobile menu
  toggleMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.toggle('hidden')
      
      // Toggle active state on menu button
      const menuButton = this.element.querySelector('[data-action*="toggleMobileMenu"]')
      if (menuButton) {
        menuButton.classList.toggle('active')
      }
    }
  }

  // Close mobile menu
  closeMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.add('hidden')
      
      const menuButton = this.element.querySelector('[data-action*="toggleMobileMenu"]')
      if (menuButton) {
        menuButton.classList.remove('active')
      }
    }
  }

  // Handle search input
  search(event) {
    this.clearSearchTimeout()
    
    this.searchTimeout = setTimeout(() => {
      this.performSearch(event.target.value)
    }, this.searchDelayValue)
  }

  // Perform the actual search
  performSearch(query) {
    // Dispatch search event for parent components to handle
    this.dispatch('search', {
      detail: {
        query: query,
        element: this.hasSearchInputTarget ? this.searchInputTarget : null
      }
    })
    
    // Auto-submit if form is present
    const form = this.hasSearchInputTarget ? this.searchInputTarget.closest('form') : null
    if (form && query.length >= 2) {
      form.requestSubmit()
    }
  }

  // Clear search timeout
  clearSearchTimeout() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
      this.searchTimeout = null
    }
  }

  // Set theme
  setTheme(event) {
    const theme = event.target.dataset.theme
    
    if (theme === 'auto') {
      localStorage.removeItem('theme')
      this.applySystemTheme()
    } else {
      localStorage.setItem('theme', theme)
      document.documentElement.setAttribute('data-theme', theme)
    }
    
    this.dispatch('themeChanged', {
      detail: { theme: theme }
    })
  }

  // Setup theme on page load
  setupTheme() {
    const savedTheme = localStorage.getItem('theme')
    
    if (savedTheme) {
      document.documentElement.setAttribute('data-theme', savedTheme)
    } else {
      this.applySystemTheme()
    }
    
    // Listen for system theme changes
    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (!localStorage.getItem('theme')) {
          this.applySystemTheme()
        }
      })
    }
  }

  // Apply system theme preference
  applySystemTheme() {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      document.documentElement.setAttribute('data-theme', 'dark')
    } else {
      document.documentElement.setAttribute('data-theme', 'light')
    }
  }

  // Handle clicks outside mobile menu to close it
  handleOutsideClicks() {
    this.outsideClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.closeMobileMenu()
      }
    }
    
    document.addEventListener('click', this.outsideClickHandler)
  }

  // Remove outside click listener
  removeOutsideClickListener() {
    if (this.outsideClickHandler) {
      document.removeEventListener('click', this.outsideClickHandler)
    }
  }

  // Dispatch custom events
  dispatch(eventName, options = {}) {
    const event = new CustomEvent(`navbar:${eventName}`, {
      detail: { controller: this, ...options.detail },
      bubbles: true,
      cancelable: true
    })
    this.element.dispatchEvent(event)
  }
}