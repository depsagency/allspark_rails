import { Controller } from "@hotwired/stimulus"

// Modal controller for DaisyUI modal components
//
// Provides functionality for:
// - Opening and closing modals
// - Backdrop click handling
// - Keyboard navigation (ESC to close)
// - Focus management
//
// Usage:
//   <dialog data-controller="modal" data-modal-closable-value="true">
//     <button data-action="click->modal#close">Close</button>
//   </dialog>
//
//   // JavaScript
//   this.application.getControllerForElementAndIdentifier(element, "modal").open()
//
export default class extends Controller {
  static values = { 
    closable: { type: Boolean, default: true },
    closeOnBackdrop: { type: Boolean, default: true },
    closeOnEscape: { type: Boolean, default: true }
  }

  static targets = ["dialog", "backdrop"]

  connect() {
    this.boundKeydownHandler = this.handleKeydown.bind(this)
    this.originalActiveElement = null
  }

  disconnect() {
    this.removeKeydownListener()
  }

  // Open the modal
  open() {
    if (this.element.tagName === 'DIALOG') {
      this.originalActiveElement = document.activeElement
      this.element.showModal()
      this.addKeydownListener()
      this.focusFirstElement()
      this.dispatch("opened")
    } else {
      this.element.classList.add('modal-open')
      this.dispatch("opened")
    }
  }

  // Close the modal
  close() {
    if (!this.closableValue) return

    if (this.element.tagName === 'DIALOG') {
      this.element.close()
      this.removeKeydownListener()
      this.restoreFocus()
      this.dispatch("closed")
    } else {
      this.element.classList.remove('modal-open')
      this.dispatch("closed")
    }
  }

  // Toggle modal state
  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  // Check if modal is open
  isOpen() {
    if (this.element.tagName === 'DIALOG') {
      return this.element.open
    } else {
      return this.element.classList.contains('modal-open')
    }
  }

  // Handle backdrop clicks
  backdropClicked(event) {
    if (!this.closeOnBackdropValue || !this.closableValue) return
    
    // Only close if clicking directly on the backdrop, not on modal content
    if (event.target === this.element || event.target.classList.contains('modal-backdrop')) {
      this.close()
    }
  }

  // Handle keyboard events
  handleKeydown(event) {
    if (!this.closeOnEscapeValue || !this.closableValue) return

    if (event.key === 'Escape') {
      event.preventDefault()
      this.close()
    } else if (event.key === 'Tab') {
      this.handleTabKey(event)
    }
  }

  // Handle tab key for focus trapping
  handleTabKey(event) {
    const focusableElements = this.getFocusableElements()
    if (focusableElements.length === 0) return

    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    if (event.shiftKey) {
      // Shift + Tab
      if (document.activeElement === firstElement) {
        event.preventDefault()
        lastElement.focus()
      }
    } else {
      // Tab
      if (document.activeElement === lastElement) {
        event.preventDefault()
        firstElement.focus()
      }
    }
  }

  // Get all focusable elements within the modal
  getFocusableElements() {
    const selectors = [
      'button:not([disabled])',
      'input:not([disabled]):not([type="hidden"])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      'a[href]',
      '[tabindex]:not([tabindex="-1"])'
    ].join(', ')

    return Array.from(this.element.querySelectorAll(selectors))
      .filter(element => {
        return element.offsetWidth > 0 && 
               element.offsetHeight > 0 && 
               !element.hidden
      })
  }

  // Focus the first focusable element
  focusFirstElement() {
    const focusableElements = this.getFocusableElements()
    if (focusableElements.length > 0) {
      focusableElements[0].focus()
    }
  }

  // Restore focus to the element that was focused before modal opened
  restoreFocus() {
    if (this.originalActiveElement && this.originalActiveElement.focus) {
      this.originalActiveElement.focus()
    }
    this.originalActiveElement = null
  }

  // Add keydown event listener
  addKeydownListener() {
    document.addEventListener('keydown', this.boundKeydownHandler)
  }

  // Remove keydown event listener
  removeKeydownListener() {
    document.removeEventListener('keydown', this.boundKeydownHandler)
  }

  // Dispatch custom events
  dispatch(eventName, detail = {}) {
    const event = new CustomEvent(`modal:${eventName}`, {
      detail: { controller: this, ...detail },
      bubbles: true,
      cancelable: true
    })
    this.element.dispatchEvent(event)
  }
}