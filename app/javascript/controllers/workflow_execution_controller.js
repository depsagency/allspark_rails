import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["status", "progress", "progressBar", "elapsed", "task", "taskStatus"]
  static values = { id: String, teamId: String, workflowId: String }
  
  connect() {
    console.log("WorkflowExecutionController connected for execution:", this.idValue)
    this.startTime = new Date()
    this.subscription = consumer.subscriptions.create(
      {
        channel: "WorkflowExecutionChannel",
        execution_id: this.idValue
      },
      {
        connected: () => {
          console.log("Connected to WorkflowExecutionChannel for execution:", this.idValue)
        },
        
        disconnected: () => {
          console.log("Disconnected from WorkflowExecutionChannel")
        },
        
        received: (data) => {
          console.log("Received message:", data)
          this.handleMessage(data)
        }
      }
    )
    
    // Update elapsed time every second
    this.elapsedInterval = setInterval(() => this.updateElapsedTime(), 1000)
  }
  
  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.elapsedInterval) {
      clearInterval(this.elapsedInterval)
    }
  }
  
  handleMessage(data) {
    switch (data.type) {
      case 'initial_status':
        this.updateExecutionStatus(data.execution)
        break
      case 'task_update':
        this.updateTask(data)
        break
      case 'task_created':
        this.addNewTask(data)
        break
      case 'execution_update':
        this.updateExecutionStatus(data)
        break
      default:
        console.log("Unknown message type:", data.type)
    }
  }
  
  updateExecutionStatus(data) {
    console.log("updateExecutionStatus called with data:", data)
    
    // Update progress
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${data.progress_percentage || 0}%`
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.value = data.progress_percentage || 0
    }
    
    // Update status text
    if (this.hasStatusTarget && data.status === 'running') {
      const runningTasks = data.tasks?.filter(t => t.status === 'running').length || 0
      const completedTasks = data.tasks?.filter(t => t.status === 'completed').length || 0
      const totalTasks = data.tasks?.length || 0
      
      this.statusTarget.textContent = `Processing ${runningTasks} task${runningTasks !== 1 ? 's' : ''}, ${completedTasks} of ${totalTasks} completed`
    }
    
    // If execution is complete, update the UI to reflect final state
    if (data.status === 'completed' || data.status === 'failed' || data.status === 'cancelled') {
      // Remove the progress alert if it exists
      const progressAlert = this.element.querySelector('.alert.alert-info')
      if (progressAlert) {
        progressAlert.remove()
      }
      
      // Update the main status badge
      const mainStatusBadge = this.element.querySelector('.flex.justify-between .badge')
      if (mainStatusBadge) {
        mainStatusBadge.textContent = data.status
        mainStatusBadge.className = `badge badge-${this.getStatusClass(data.status)} badge-lg`
      }
      
      // Update execution summary status
      const summaryStatusBadge = this.element.querySelector('.card-body .badge')
      if (summaryStatusBadge) {
        summaryStatusBadge.textContent = data.status
        summaryStatusBadge.className = `badge badge-${this.getStatusClass(data.status)} badge-lg`
      }
      
      // Show action buttons based on status
      const cancelButton = this.element.querySelector('a[href*="cancel"]')
      const runAgainButton = this.element.querySelector('a[href*="execute"]')
      
      if (cancelButton) cancelButton.style.display = 'none'
      if (runAgainButton) runAgainButton.style.display = 'inline-flex'
    }
  }
  
  updateTask(data) {
    console.log("updateTask called with data:", data)
    const taskElement = this.findTaskElement(data.task_id)
    if (!taskElement) {
      console.error(`Task element not found for task_id: ${data.task_id}`)
      console.log("Available task elements:", this.taskTargets.map(el => el.dataset.taskId))
      return
    }
    
    // Update task status badge
    const statusBadge = taskElement.querySelector('[data-workflow-execution-target="taskStatus"]')
    if (statusBadge) {
      statusBadge.textContent = data.status
      statusBadge.className = `badge badge-${this.getStatusClass(data.status)}`
    }
    
    // Update task details if expanded
    const detailsContainer = taskElement.querySelector('.collapse-content')
    if (detailsContainer && data.completed_at) {
      // Update completed time
      const completedElement = detailsContainer.querySelector('[data-field="completed"]')
      if (completedElement) {
        completedElement.textContent = new Date(data.completed_at).toLocaleTimeString()
      }
      
      // Update duration
      const durationElement = detailsContainer.querySelector('[data-field="duration"]')
      if (durationElement && data.started_at) {
        const duration = new Date(data.completed_at) - new Date(data.started_at)
        durationElement.textContent = this.formatDuration(duration)
      }
      
      // Update result if present
      if (data.result_data) {
        this.updateTaskResult(detailsContainer, data.result_data)
      }
    }
    
    // Update task statistics in sidebar
    this.updateTaskStatistics()
  }
  
  addNewTask(data) {
    const tasksContainer = this.element.querySelector('.space-y-4')
    if (!tasksContainer) return
    
    // Remove empty state message if present
    const emptyMessage = tasksContainer.querySelector('.text-center.py-8')
    if (emptyMessage) {
      emptyMessage.remove()
    }
    
    // Create new task element
    const taskHtml = this.createTaskHtml(data.task)
    tasksContainer.insertAdjacentHTML('beforeend', taskHtml)
    
    // Update task statistics
    this.updateTaskStatistics()
  }
  
  createTaskHtml(task) {
    return `
      <div class="collapse collapse-arrow bg-base-200" 
           data-workflow-execution-target="task"
           data-task-id="${task.id}">
        <input type="checkbox" ${task.status === 'running' || task.status === 'failed' ? 'checked' : ''} />
        <div class="collapse-title">
          <div class="flex items-center justify-between">
            <div>
              <h4 class="font-semibold">${task.title}</h4>
              <p class="text-sm opacity-70">
                Node: ${task.node_id} • 
                ${task.assistant_name ? `Assigned to: ${task.assistant_name}` : 'Unassigned'}
              </p>
            </div>
            <div class="badge badge-${this.getStatusClass(task.status)}"
                 data-workflow-execution-target="taskStatus">
              ${task.status}
            </div>
          </div>
        </div>
        <div class="collapse-content">
          <div class="space-y-3">
            ${task.instructions ? `
              <div>
                <h5 class="font-semibold text-sm mb-1">Instructions:</h5>
                <p class="text-sm bg-base-100 p-3 rounded">${task.instructions}</p>
              </div>
            ` : ''}
            
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span class="font-semibold">Started:</span>
                <span data-field="started">${task.started_at ? new Date(task.started_at).toLocaleTimeString() : 'Not started'}</span>
              </div>
              <div>
                <span class="font-semibold">Completed:</span>
                <span data-field="completed">${task.completed_at ? new Date(task.completed_at).toLocaleTimeString() : '—'}</span>
              </div>
              <div>
                <span class="font-semibold">Duration:</span>
                <span data-field="duration">—</span>
              </div>
              <div>
                <span class="font-semibold">Status:</span>
                <span class="badge badge-sm badge-${this.getStatusClass(task.status)}">
                  ${task.status}
                </span>
              </div>
            </div>
            
            <div class="task-result-container"></div>
          </div>
        </div>
      </div>
    `
  }
  
  updateTaskResult(container, resultData) {
    let resultContainer = container.querySelector('.task-result-container')
    if (!resultContainer) {
      resultContainer = document.createElement('div')
      resultContainer.className = 'task-result-container'
      container.querySelector('.space-y-3').appendChild(resultContainer)
    }
    
    let resultHtml = '<div><h5 class="font-semibold text-sm mb-1">Result:</h5><div class="bg-base-100 p-3 rounded">'
    
    if (resultData.result || resultData.output) {
      resultHtml += `<div class="prose prose-sm max-w-none">${this.formatResult(resultData.result || resultData.output)}</div>`
    } else if (resultData.error) {
      resultHtml += `<div class="text-error">Error: ${resultData.error}</div>`
    } else {
      resultHtml += `<pre class="text-sm">${JSON.stringify(resultData, null, 2)}</pre>`
    }
    
    resultHtml += '</div></div>'
    resultContainer.innerHTML = resultHtml
  }
  
  findTaskElement(taskId) {
    // Convert both to strings and handle potential type mismatches
    const searchId = String(taskId)
    return this.taskTargets.find(el => {
      const elementId = String(el.dataset.taskId)
      return elementId === searchId
    })
  }
  
  updateTaskStatistics() {
    const tasks = this.taskTargets
    const stats = {
      total: tasks.length,
      completed: 0,
      running: 0,
      pending: 0,
      failed: 0
    }
    
    tasks.forEach(task => {
      const status = task.querySelector('[data-workflow-execution-target="taskStatus"]')?.textContent
      if (status === 'completed') stats.completed++
      else if (status === 'running') stats.running++
      else if (status === 'failed') stats.failed++
      else if (status === 'pending') stats.pending++
    })
    
    // Update statistics in sidebar
    document.querySelectorAll('[data-stat]').forEach(el => {
      const stat = el.dataset.stat
      if (stats[stat] !== undefined) {
        el.textContent = stats[stat]
      }
    })
  }
  
  updateElapsedTime() {
    if (this.hasElapsedTarget) {
      const elapsed = new Date() - this.startTime
      this.elapsedTarget.textContent = this.formatDuration(elapsed)
    }
  }
  
  formatDuration(milliseconds) {
    const seconds = Math.floor(milliseconds / 1000)
    const minutes = Math.floor(seconds / 60)
    const hours = Math.floor(minutes / 60)
    
    if (hours > 0) {
      return `${hours}h ${minutes % 60}m`
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`
    } else {
      return `${seconds}s`
    }
  }
  
  formatResult(text) {
    // Convert newlines to <br> tags for proper formatting
    return text.replace(/\n/g, '<br>')
  }
  
  getStatusClass(status) {
    switch (status) {
      case 'completed': return 'success'
      case 'failed': return 'error'
      case 'running': return 'warning'
      case 'cancelled': return 'ghost'
      default: return 'info'
    }
  }
}