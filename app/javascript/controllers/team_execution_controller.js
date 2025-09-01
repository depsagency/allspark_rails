import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["progress", "results", "status"]
  static values = { executionId: String }

  connect() {
    if (this.hasExecutionIdValue) {
      this.subscribe()
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribe() {
    this.subscription = consumer.subscriptions.create(
      { 
        channel: "TeamExecutionChannel",
        execution_id: this.executionIdValue
      },
      {
        received: (data) => {
          this.handleProgress(data)
        }
      }
    )
  }

  handleProgress(data) {
    switch(data.event) {
      case 'started':
        this.showProgress("Starting task execution...")
        break
      
      case 'plan_created':
        this.showProgress(`Created plan with ${data.data.total_steps} steps`)
        break
      
      case 'step_started':
        this.showProgress(`Step ${data.data.step_number}/${data.data.total_steps}: ${data.data.step.action}`)
        this.updateStepStatus(data.data.step_number, 'running')
        break
      
      case 'step_completed':
        const status = data.data.result.status === 'completed' ? 'completed' : 'failed'
        this.updateStepStatus(data.data.step_number, status)
        break
      
      case 'completed':
        this.showProgress(`Execution completed with status: ${data.data.status}`)
        this.updateExecutionStatus(data.data.status)
        // Reload the page to show final results
        setTimeout(() => window.location.reload(), 1500)
        break
    }
  }

  showProgress(message) {
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = message
      this.progressTarget.classList.remove('hidden')
    }
  }

  updateStepStatus(stepNumber, status) {
    const stepElement = this.element.querySelector(`[data-step-number="${stepNumber}"]`)
    if (stepElement) {
      stepElement.dataset.status = status
      
      // Update visual indicator
      const badge = stepElement.querySelector('.badge')
      if (badge) {
        badge.classList.remove('badge-ghost', 'badge-warning', 'badge-success', 'badge-error')
        switch(status) {
          case 'running':
            badge.classList.add('badge-warning')
            badge.textContent = 'Running'
            break
          case 'completed':
            badge.classList.add('badge-success')
            badge.textContent = 'Completed'
            break
          case 'failed':
            badge.classList.add('badge-error')
            badge.textContent = 'Failed'
            break
        }
      }
    }
  }

  updateExecutionStatus(status) {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.remove('badge-warning', 'badge-success', 'badge-error')
      this.statusTarget.classList.add(status === 'completed' ? 'badge-success' : 'badge-error')
      this.statusTarget.textContent = status
    }
  }
}