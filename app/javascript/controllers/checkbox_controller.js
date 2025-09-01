import { Controller } from "@hotwired/stimulus"

// Checkbox controller for enhanced checkbox functionality
//
// Provides functionality for:
// - Indeterminate state management
// - Grouped checkbox behavior
// - Custom change events
//
// Usage:
//   <input data-controller="checkbox" data-indeterminate="true" type="checkbox">
//
export default class extends Controller {
  static values = {
    indeterminate: { type: Boolean, default: false }
  }

  connect() {
    this.updateIndeterminateState()
  }

  indeterminateValueChanged() {
    this.updateIndeterminateState()
  }

  // Update the indeterminate state
  updateIndeterminateState() {
    if (this.element.type === 'checkbox') {
      this.element.indeterminate = this.indeterminateValue
    }
  }

  // Handle checkbox change
  change(event) {
    // Clear indeterminate state when checkbox is clicked
    if (this.indeterminateValue && this.element.indeterminate) {
      this.indeterminateValue = false
      this.element.indeterminate = false
    }

    this.dispatch('change', {
      detail: {
        checked: this.element.checked,
        value: this.element.value,
        name: this.element.name
      }
    })
  }

  // Set indeterminate state
  setIndeterminate(indeterminate = true) {
    this.indeterminateValue = indeterminate
    this.updateIndeterminateState()
  }

  // Check the checkbox
  check() {
    this.element.checked = true
    this.indeterminateValue = false
    this.updateIndeterminateState()
    this.element.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // Uncheck the checkbox
  uncheck() {
    this.element.checked = false
    this.indeterminateValue = false
    this.updateIndeterminateState()
    this.element.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // Toggle the checkbox
  toggle() {
    if (this.element.checked) {
      this.uncheck()
    } else {
      this.check()
    }
  }

  // Dispatch custom events
  dispatch(eventName, options = {}) {
    const event = new CustomEvent(`checkbox:${eventName}`, {
      detail: { controller: this, ...options.detail },
      bubbles: true,
      cancelable: true
    })
    this.element.dispatchEvent(event)
  }
}