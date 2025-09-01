import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { projectId: String }

  connect() {
    console.log('Serialize controller connected')
    // Extract project slug from current URL as fallback
    const urlParts = window.location.pathname.split('/')
    const projectSlug = urlParts[urlParts.indexOf('app_projects') + 1]
    console.log('Project slug from URL:', projectSlug)
    console.log('Project ID (from value):', this.projectIdValue)
    console.log('Element dataset:', this.element.dataset)
    
    // Use projectId value if available, otherwise fall back to URL
    this.currentProjectId = this.projectIdValue || projectSlug
    console.log('Using project ID:', this.currentProjectId)
  }

  async serialize(event) {
    console.log('Serialize button clicked')
    const button = event.currentTarget
    const outputType = button.dataset.outputType
    const force = button.dataset.force === 'true'
    
    console.log('Output type:', outputType)
    console.log('Button:', button)
    
    if (!outputType) {
      console.error('Output type not specified')
      return
    }

    // Update button state
    this.setButtonState(button, 'loading')
    
    console.log('Using project ID for URL:', this.currentProjectId)
    
    try {
      const response = await fetch(`/app_projects/${this.currentProjectId}/serialize_output`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({
          output_type: outputType,
          force: force
        })
      })

      const data = await response.json()
      console.log('Response status:', response.status)
      console.log('Response data:', data)

      if (response.ok) {
        this.setButtonState(button, 'success')
        this.showToast(`${outputType.replace(/_/g, ' ')} serialized successfully!`, 'success')
        
        // Reset button after 2 seconds
        setTimeout(() => {
          this.setButtonState(button, 'default')
        }, 2000)
      } else {
        this.setButtonState(button, 'error')
        this.showToast(data.message || 'Serialization failed', 'error')
        
        // Reset button after 3 seconds
        setTimeout(() => {
          this.setButtonState(button, 'default')
        }, 3000)
      }
    } catch (error) {
      console.error('Serialization error:', error)
      this.setButtonState(button, 'error')
      this.showToast('Network error occurred', 'error')
      
      // Reset button after 3 seconds
      setTimeout(() => {
        this.setButtonState(button, 'default')
      }, 3000)
    }
  }

  setButtonState(button, state) {
    const textSpan = button.querySelector('.serialize-text')
    const spinner = button.querySelector('.loading')
    
    // Reset classes
    button.classList.remove('btn-success', 'btn-error', 'btn-disabled')
    
    // Only manipulate elements if they exist
    if (textSpan) {
      textSpan.classList.remove('hidden')
    }
    if (spinner) {
      spinner.classList.add('hidden')
    }
    
    switch (state) {
      case 'loading':
        button.classList.add('btn-disabled')
        button.disabled = true
        if (textSpan) {
          textSpan.classList.add('hidden')
        }
        if (spinner) {
          spinner.classList.remove('hidden')
        }
        break
        
      case 'success':
        button.classList.add('btn-success')
        button.disabled = false
        if (textSpan) {
          textSpan.textContent = 'Serialized ✓'
        }
        break
        
      case 'error':
        button.classList.add('btn-error')
        button.disabled = false
        if (textSpan) {
          textSpan.textContent = 'Error ⚠'
        }
        break
        
      case 'default':
      default:
        button.classList.add('btn-success')
        button.disabled = false
        if (textSpan) {
          textSpan.textContent = 'Serialize'
        }
        break
    }
  }

  showToast(message, type = 'info') {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = `alert alert-${type} fixed top-4 right-4 w-auto max-w-sm z-50 shadow-lg`
    toast.innerHTML = `
      <div class="flex items-center gap-2">
        <span>${message}</span>
        <button class="btn btn-ghost btn-xs" onclick="this.parentElement.parentElement.remove()">✕</button>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove()
      }
    }, 5000)
  }
}