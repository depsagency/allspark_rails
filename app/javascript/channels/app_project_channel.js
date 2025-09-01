import consumer from "channels/consumer"

// App Project real-time updates channel
class AppProjectChannel {
  constructor(projectId) {
    this.projectId = projectId
    this.subscription = null
    this.callbacks = {
      progress: [],
      update: [],
      error: [],
      connected: [],
      status: []
    }
  }

  subscribe() {
    if (this.subscription) {
      this.unsubscribe()
    }

    this.subscription = consumer.subscriptions.create(
      { 
        channel: "AppProjectChannel", 
        project_id: this.projectId 
      },
      {
        connected: () => {
          console.log("Connected to AppProjectChannel")
          this.trigger('connected', { connected: true })
        },

        disconnected: () => {
          console.log("Disconnected from AppProjectChannel")
          this.trigger('connected', { connected: false })
        },

        received: (data) => {
          console.log("Received from AppProjectChannel:", data)
          this.handleMessage(data)
        }
      }
    )

    return this.subscription
  }

  unsubscribe() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  requestStatus() {
    if (this.subscription) {
      this.subscription.perform('request_status', { project_id: this.projectId })
    }
  }

  handleMessage(data) {
    switch (data.type) {
      case 'progress':
        this.updateProgress(data.percentage, data.message)
        this.trigger('progress', data)
        break
      
      case 'update':
        this.updateStatus(data.message, data.status)
        this.trigger('update', data)
        break
      
      case 'error':
        this.showError(data.message)
        this.trigger('error', data)
        break
      
      case 'connected':
      case 'status_update':
        this.updatePageStatus(data)
        this.trigger('status', data)
        break
      
      default:
        console.log('Unknown message type:', data.type)
    }
  }

  updateProgress(percentage, message) {
    // Update progress bars
    const progressBars = document.querySelectorAll('.generation-progress')
    progressBars.forEach(bar => {
      bar.value = percentage
      bar.classList.remove('hidden')
    })

    // Update progress text
    const progressTexts = document.querySelectorAll('.generation-progress-text')
    progressTexts.forEach(text => {
      text.textContent = `${percentage}%`
    })

    // Update status message
    const statusMessages = document.querySelectorAll('.generation-status')
    statusMessages.forEach(msg => {
      msg.textContent = message
      msg.className = 'generation-status text-sm text-blue-600'
    })
  }

  updateStatus(message, status) {
    // Update status badges
    const statusBadges = document.querySelectorAll('.project-status-badge')
    statusBadges.forEach(badge => {
      badge.textContent = status.humanize()
      badge.className = `project-status-badge badge ${this.getStatusBadgeClass(status)}`
    })

    // Update status messages
    const statusMessages = document.querySelectorAll('.generation-status')
    statusMessages.forEach(msg => {
      msg.textContent = message
      msg.className = 'generation-status text-sm text-green-600'
    })

    // Show completion message if all done
    if (status === 'prompts_generated') {
      this.showCompletionMessage()
    }
  }

  showError(message) {
    // Show error alert
    const alert = document.createElement('div')
    alert.className = 'alert alert-error mt-4'
    alert.innerHTML = `
      <div>
        <h3 class="font-bold">Generation Error</h3>
        <div class="text-sm">${message}</div>
      </div>
    `

    // Insert at top of main content
    const mainContent = document.querySelector('.container')
    if (mainContent) {
      mainContent.insertBefore(alert, mainContent.firstChild)

      // Auto-remove after 10 seconds
      setTimeout(() => {
        if (alert.parentNode) {
          alert.parentNode.removeChild(alert)
        }
      }, 10000)
    }

    // Update status messages
    const statusMessages = document.querySelectorAll('.generation-status')
    statusMessages.forEach(msg => {
      msg.textContent = message
      msg.className = 'generation-status text-sm text-red-600'
    })
  }

  updatePageStatus(data) {
    // Update completion percentage displays
    const completionElements = document.querySelectorAll('[data-completion-percentage]')
    completionElements.forEach(el => {
      el.textContent = `${data.completion_percentage}%`
    })

    // Update generation buttons visibility
    this.updateGenerationButtons(data)
  }

  updateGenerationButtons(data) {
    const generateButtons = document.querySelectorAll('.generate-prd-btn')
    const regenerateButtons = document.querySelectorAll('.regenerate-btn')
    
    if (data.status === 'generating') {
      generateButtons.forEach(btn => {
        btn.disabled = true
        btn.textContent = 'Generating...'
      })
    } else {
      generateButtons.forEach(btn => {
        btn.disabled = false
        btn.textContent = data.has_outputs ? 'Regenerate' : 'Generate PRD'
      })
    }
  }

  showCompletionMessage() {
    const alert = document.createElement('div')
    alert.className = 'alert alert-success mt-4'
    alert.innerHTML = `
      <div>
        <h3 class="font-bold">Generation Complete!</h3>
        <div class="text-sm">Your PRD, task breakdown, and Claude prompts are ready.</div>
        <div class="mt-2">
          <button class="btn btn-sm btn-outline" onclick="location.reload()">
            Refresh Page
          </button>
        </div>
      </div>
    `

    // Insert at top of main content
    const mainContent = document.querySelector('.container')
    if (mainContent) {
      mainContent.insertBefore(alert, mainContent.firstChild)
    }
  }

  getStatusBadgeClass(status) {
    switch (status) {
      case 'draft':
        return 'badge-ghost'
      case 'generating':
        return 'badge-warning'
      case 'prd_generated':
        return 'badge-info'
      case 'tasks_generated':
        return 'badge-secondary'
      case 'prompts_generated':
        return 'badge-success'
      case 'generation_failed':
        return 'badge-error'
      default:
        return 'badge-ghost'
    }
  }

  // Event system for components to listen to updates
  on(event, callback) {
    if (this.callbacks[event]) {
      this.callbacks[event].push(callback)
    }
  }

  off(event, callback) {
    if (this.callbacks[event]) {
      const index = this.callbacks[event].indexOf(callback)
      if (index > -1) {
        this.callbacks[event].splice(index, 1)
      }
    }
  }

  trigger(event, data) {
    if (this.callbacks[event]) {
      this.callbacks[event].forEach(callback => {
        try {
          callback(data)
        } catch (error) {
          console.error('Error in callback:', error)
        }
      })
    }
  }
}

// Auto-initialize if project ID is available
document.addEventListener('DOMContentLoaded', () => {
  const projectElement = document.querySelector('[data-app-project-id]')
  if (projectElement) {
    const projectId = projectElement.dataset.appProjectId
    const channel = new AppProjectChannel(projectId)
    channel.subscribe()
    
    // Make available globally for debugging
    window.appProjectChannel = channel
  }
})

export default AppProjectChannel