import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="badge-component"
export default class extends Controller {
  static targets = ["element"]
  static values = { 
    variant: String,
    size: String,
    disabled: Boolean
  }

  connect() {
    console.log("BadgeComponent controller connected")
    this.initializeComponent()
  }

  disconnect() {
    this.cleanupComponent()
  }

  // Lifecycle methods
  initializeComponent() {
    this.updateState()
  }

  cleanupComponent() {
    // Clean up any event listeners or timers here
  }

  // State management
  variantValueChanged() {
    this.updateState()
  }

  sizeValueChanged() {
    this.updateState()
  }

  disabledValueChanged() {
    this.updateState()
  }

  updateState() {
    // Update component based on current values
    this.element.classList.toggle("badge--disabled", this.disabledValue)
    
    // Update variant classes
    this.clearVariantClasses()
    this.element.classList.add(`badge--${this.variantValue || 'primary'}`)
    
    // Update size classes  
    this.clearSizeClasses()
    this.element.classList.add(`badge--${this.sizeValue || 'md'}`)
  }

  // Action methods (add your component-specific actions here)
  
  // Example action method:
  // click(event) {
  //   if (this.disabledValue) return
  //   
  //   // Handle click action
  //   this.dispatch("clicked", { 
  //     detail: { 
  //       variant: this.variantValue,
  //       size: this.sizeValue 
  //     } 
  //   })
  // }

  // Private methods
  clearVariantClasses() {
    const variants = ['badge--success,warning,error']
    variants.forEach(variant => this.element.classList.remove(variant))
  }

  clearSizeClasses() {
    const sizes = ["badge--xs", "badge--sm", "badge--md", "badge--lg"]
    sizes.forEach(size => this.element.classList.remove(size))
  }
}