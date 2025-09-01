import { Controller } from "@hotwired/stimulus"

// Alert controller for dismissible alerts
//
// Provides functionality for:
// - Dismissing alerts with animation
// - Auto-dismiss with timeout
// - Custom dismiss events
//
// Usage:
//   <div data-controller="alert" data-alert-auto-dismiss-value="5000">
//     <button data-action="click->alert#dismiss">Close</button>
//   </div>
//
export default class extends Controller {
  static values = {
    autoDismiss: { type: Number, default: 0 }, // 0 = no auto-dismiss
    animation: { type: String, default: "fade" }
  }

  connect() {
    this.setupAutoDismiss()
  }

  disconnect() {
    this.clearAutoDismiss()
  }

  // Dismiss the alert
  dismiss() {
    this.clearAutoDismiss()
    
    if (this.animationValue === "slide") {
      this.slideOut()
    } else {
      this.fadeOut()
    }
  }

  // Setup auto-dismiss timer
  setupAutoDismiss() {
    if (this.autoDismissValue > 0) {
      this.autoDismissTimer = setTimeout(() => {
        this.dismiss()
      }, this.autoDismissValue)
    }
  }

  // Clear auto-dismiss timer
  clearAutoDismiss() {
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer)
      this.autoDismissTimer = null
    }
  }

  // Fade out animation
  fadeOut() {
    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"
    
    setTimeout(() => {
      this.remove()
    }, 300)
  }

  // Slide out animation
  slideOut() {
    const height = this.element.offsetHeight
    this.element.style.transition = "all 0.3s ease-out"
    this.element.style.transform = "translateX(100%)"
    this.element.style.opacity = "0"
    
    setTimeout(() => {
      this.remove()
    }, 300)
  }

  // Remove the element
  remove() {
    this.dispatch("dismissed", { detail: { element: this.element } })
    this.element.remove()
  }

  // Dispatch custom events
  dispatch(eventName, options = {}) {
    const event = new CustomEvent(`alert:${eventName}`, {
      detail: { controller: this, ...options.detail },
      bubbles: true,
      cancelable: true
    })
    this.element.dispatchEvent(event)
  }
}