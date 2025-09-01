import { Controller } from "@hotwired/stimulus"

// Auto-save controller for wizard forms
// 
// Usage:
//   <form data-controller="autosave" 
//         data-autosave-url-value="/projects/123" 
//         data-autosave-method-value="PATCH">
//     <textarea data-action="input->autosave#scheduleAutoSave" 
//               data-autosave-target="field"></textarea>
//     <div data-autosave-target="status">Saved</div>
//   </form>
//
export default class extends Controller {
  static values = { 
    url: String, 
    method: String 
  }
  
  static targets = ["field", "status"]

  connect() {
    this.timeout = null
    this.lastSavedValue = this.getFormData()
    this.updateStatus("Auto-save ready", "text-gray-500")
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  scheduleAutoSave() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    this.updateStatus("Typing...", "text-blue-500")
    
    this.timeout = setTimeout(() => {
      this.autoSave()
    }, 2000) // Wait 2 seconds after user stops typing
  }

  async autoSave() {
    const currentData = this.getFormData()
    
    // Don't save if nothing has changed
    if (JSON.stringify(currentData) === JSON.stringify(this.lastSavedValue)) {
      this.updateStatus("No changes", "text-gray-500")
      return
    }

    this.updateStatus("Saving...", "text-blue-500")

    try {
      const response = await fetch(this.urlValue, {
        method: this.methodValue || 'PATCH',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': this.getCSRFToken(),
          'Accept': 'application/json'
        },
        body: new URLSearchParams(currentData)
      })

      if (response.ok) {
        const result = await response.json()
        this.lastSavedValue = currentData
        this.updateStatus("Saved ✓", "text-green-600")
        
        // Update completion percentage if provided
        if (result.completion_percentage !== undefined) {
          this.updateCompletionIndicators(result.completion_percentage)
        }
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      console.error('Auto-save failed:', error)
      this.updateStatus("Save failed", "text-red-500")
      
      // Retry after 5 seconds
      setTimeout(() => {
        this.autoSave()
      }, 5000)
    }
  }

  updateStatus(message, className) {
    this.statusTargets.forEach(target => {
      target.textContent = message
      target.className = `text-sm ${className}`
    })
  }

  updateCompletionIndicators(percentage) {
    // Update progress bars
    const progressBars = document.querySelectorAll('progress')
    progressBars.forEach(bar => {
      if (bar.max == 100) {
        bar.value = percentage
      }
    })
    
    // Update percentage text
    const percentageTexts = document.querySelectorAll('[data-completion-percentage]')
    percentageTexts.forEach(text => {
      text.textContent = `${percentage}%`
    })
  }

  getFormData() {
    const formData = new FormData(this.element)
    const data = {}
    
    for (let [key, value] of formData.entries()) {
      // Skip certain fields that shouldn't trigger saves
      if (!['authenticity_token', 'step', 'project_slug'].includes(key)) {
        data[key] = value
      }
    }
    
    return data
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
}