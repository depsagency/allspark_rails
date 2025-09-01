import consumer from "./consumer"

// Live Updates Channel for real-time data synchronization
//
// Handles:
// - Real-time model updates
// - Live data feeds
// - Collaborative editing
// - Resource-specific updates
//
class LiveUpdatesChannel {
  constructor() {
    this.subscription = null
    this.subscribedResources = new Set()
    this.subscribedModels = new Set()
    this.callbacks = {
      resourceUpdate: [],
      modelUpdate: [],
      userUpdate: [],
      cursorUpdate: [],
      selectionUpdate: [],
      connected: [],
      disconnected: []
    }
    
    this.connect()
  }

  connect() {
    this.subscription = consumer.subscriptions.create("LiveUpdatesChannel", {
      connected: () => {
        console.log("Connected to LiveUpdatesChannel")
        // Subscribe to user-specific updates
        this.subscription.perform('follow_user_updates')
        this.trigger('connected')
      },

      disconnected: () => {
        console.log("Disconnected from LiveUpdatesChannel")
        this.trigger('disconnected')
      },

      received: (data) => {
        this.handleUpdate(data)
      }
    })
  }

  handleUpdate(data) {
    switch (data.type) {
      case 'resource_updated':
        this.handleResourceUpdate(data)
        break
        
      case 'resource_created':
        this.handleResourceCreated(data)
        break
        
      case 'resource_deleted':
        this.handleResourceDeleted(data)
        break
        
      case 'model_updated':
        this.handleModelUpdate(data)
        break
        
      case 'user_update':
        this.handleUserUpdate(data)
        break
        
      case 'cursor_update':
        this.handleCursorUpdate(data)
        break
        
      case 'selection_update':
        this.handleSelectionUpdate(data)
        break
        
      case 'subscribed_to_resource':
      case 'unsubscribed_from_resource':
      case 'subscribed_to_model':
      case 'unsubscribed_from_model':
      case 'subscribed_to_user_updates':
        console.log(`LiveUpdates: ${data.type}`, data)
        break
    }
  }

  handleResourceUpdate(data) {
    const { resource_type, resource_id, resource_data, changes, user } = data
    
    // Update DOM elements with matching data attributes
    this.updateResourceElements(resource_type, resource_id, resource_data, changes)
    
    // Trigger callbacks
    this.trigger('resourceUpdate', {
      type: resource_type,
      id: resource_id,
      data: resource_data,
      changes: changes,
      user: user
    })
    
    // Show update notification if user preference is enabled
    if (this.shouldShowUpdateNotification(data)) {
      this.showUpdateNotification(data)
    }
  }

  handleResourceCreated(data) {
    const { resource_type, resource_data, user } = data
    
    // Add new element to lists
    this.addResourceToLists(resource_type, resource_data)
    
    // Trigger callbacks
    this.trigger('resourceUpdate', {
      type: resource_type,
      action: 'created',
      data: resource_data,
      user: user
    })
  }

  handleResourceDeleted(data) {
    const { resource_type, resource_id, user } = data
    
    // Remove elements from DOM
    this.removeResourceElements(resource_type, resource_id)
    
    // Trigger callbacks
    this.trigger('resourceUpdate', {
      type: resource_type,
      id: resource_id,
      action: 'deleted',
      user: user
    })
  }

  handleModelUpdate(data) {
    // Handle global model updates
    this.trigger('modelUpdate', data)
  }

  handleUserUpdate(data) {
    // Handle user-specific updates
    this.trigger('userUpdate', data)
  }

  handleCursorUpdate(data) {
    const { user, position } = data
    
    // Update cursor positions in collaborative editor
    this.updateCollaborativeCursor(user, position)
    
    this.trigger('cursorUpdate', { user, position })
  }

  handleSelectionUpdate(data) {
    const { user, selection } = data
    
    // Update selection highlights in collaborative editor
    this.updateCollaborativeSelection(user, selection)
    
    this.trigger('selectionUpdate', { user, selection })
  }

  // Subscription management
  followResource(resourceType, resourceId) {
    if (this.subscription) {
      const key = `${resourceType}:${resourceId}`
      if (!this.subscribedResources.has(key)) {
        this.subscription.perform('follow_resource', {
          resource_type: resourceType,
          resource_id: resourceId
        })
        this.subscribedResources.add(key)
      }
    }
  }

  unfollowResource(resourceType, resourceId) {
    if (this.subscription) {
      const key = `${resourceType}:${resourceId}`
      if (this.subscribedResources.has(key)) {
        this.subscription.perform('unfollow_resource', {
          resource_type: resourceType,
          resource_id: resourceId
        })
        this.subscribedResources.delete(key)
      }
    }
  }

  followModel(modelType) {
    if (this.subscription) {
      if (!this.subscribedModels.has(modelType)) {
        this.subscription.perform('follow_model', {
          model_type: modelType
        })
        this.subscribedModels.add(modelType)
      }
    }
  }

  unfollowModel(modelType) {
    if (this.subscription) {
      if (this.subscribedModels.has(modelType)) {
        this.subscription.perform('unfollow_model', {
          model_type: modelType
        })
        this.subscribedModels.delete(modelType)
      }
    }
  }

  followUserUpdates() {
    if (this.subscription) {
      this.subscription.perform('follow_user_updates')
    }
  }

  // Collaborative editing methods
  updateCursorPosition(resourceType, resourceId, position) {
    if (this.subscription) {
      this.subscription.perform('update_cursor_position', {
        resource_type: resourceType,
        resource_id: resourceId,
        position: position
      })
    }
  }

  updateSelection(resourceType, resourceId, selection) {
    if (this.subscription) {
      this.subscription.perform('update_selection', {
        resource_type: resourceType,
        resource_id: resourceId,
        selection: selection
      })
    }
  }

  // DOM update methods
  updateResourceElements(resourceType, resourceId, resourceData, changes) {
    // Find elements with data attributes matching the resource
    const selectors = [
      `[data-${resourceType}-id="${resourceId}"]`,
      `[data-resource-type="${resourceType}"][data-resource-id="${resourceId}"]`,
      `.${resourceType}-${resourceId}`
    ]
    
    selectors.forEach(selector => {
      const elements = document.querySelectorAll(selector)
      elements.forEach(element => {
        this.updateElementFromResource(element, resourceData, changes)
      })
    })
  }

  updateElementFromResource(element, resourceData, changes) {
    // Update text content for specific attributes
    Object.keys(changes || {}).forEach(attribute => {
      const attributeElements = element.querySelectorAll(`[data-attribute="${attribute}"]`)
      attributeElements.forEach(el => {
        el.textContent = resourceData[attribute] || ''
      })
    })
    
    // Update the entire element if it has a data-update-method
    const updateMethod = element.dataset.updateMethod
    if (updateMethod && typeof window[updateMethod] === 'function') {
      window[updateMethod](element, resourceData, changes)
    }
    
    // Add visual feedback for updates
    this.addUpdateFeedback(element)
  }

  addResourceToLists(resourceType, resourceData) {
    // Find list containers for this resource type
    const containers = document.querySelectorAll(`[data-resource-list="${resourceType}"]`)
    
    containers.forEach(container => {
      const template = container.querySelector('[data-resource-template]')
      if (template) {
        const newElement = this.createElementFromTemplate(template, resourceData)
        
        // Insert based on sort order or at the top
        const sortBy = container.dataset.sortBy
        if (sortBy && resourceData[sortBy]) {
          this.insertSorted(container, newElement, sortBy, resourceData[sortBy])
        } else {
          container.insertBefore(newElement, container.firstChild)
        }
        
        // Add animation
        this.animateElementIn(newElement)
      }
    })
  }

  removeResourceElements(resourceType, resourceId) {
    const selectors = [
      `[data-${resourceType}-id="${resourceId}"]`,
      `[data-resource-type="${resourceType}"][data-resource-id="${resourceId}"]`,
      `.${resourceType}-${resourceId}`
    ]
    
    selectors.forEach(selector => {
      const elements = document.querySelectorAll(selector)
      elements.forEach(element => {
        this.animateElementOut(element, () => {
          element.remove()
        })
      })
    })
  }

  createElementFromTemplate(template, resourceData) {
    const clone = template.cloneNode(true)
    clone.removeAttribute('data-resource-template')
    clone.style.display = ''
    
    // Replace placeholders in the template
    const html = clone.innerHTML.replace(/\{\{(\w+)\}\}/g, (match, key) => {
      return this.escapeHtml(resourceData[key] || '')
    })
    clone.innerHTML = html
    
    // Set data attributes
    Object.keys(resourceData).forEach(key => {
      if (key === 'id') {
        clone.setAttribute(`data-${template.dataset.resourceType || 'resource'}-id`, resourceData[key])
      }
    })
    
    return clone
  }

  // Collaborative editing UI updates
  updateCollaborativeCursor(user, position) {
    const editorContainer = document.querySelector('[data-collaborative-editor]')
    if (!editorContainer) return
    
    let cursor = editorContainer.querySelector(`[data-user-cursor="${user.id}"]`)
    
    if (!cursor) {
      cursor = this.createCollaborativeCursor(user)
      editorContainer.appendChild(cursor)
    }
    
    // Update cursor position
    cursor.style.left = `${position.x}px`
    cursor.style.top = `${position.y}px`
    
    // Show cursor name temporarily
    this.showCursorName(cursor, user.name)
  }

  updateCollaborativeSelection(user, selection) {
    const editorContainer = document.querySelector('[data-collaborative-editor]')
    if (!editorContainer) return
    
    // Remove existing selection for this user
    const existingSelection = editorContainer.querySelector(`[data-user-selection="${user.id}"]`)
    if (existingSelection) {
      existingSelection.remove()
    }
    
    // Create new selection highlight
    if (selection && selection.start && selection.end) {
      const selectionElement = this.createCollaborativeSelection(user, selection)
      editorContainer.appendChild(selectionElement)
    }
  }

  createCollaborativeCursor(user) {
    const cursor = document.createElement('div')
    cursor.className = 'collaborative-cursor absolute z-50 pointer-events-none'
    cursor.setAttribute('data-user-cursor', user.id)
    cursor.style.borderLeft = `2px solid ${user.color}`
    cursor.style.height = '20px'
    cursor.style.marginLeft = '-1px'
    
    const label = document.createElement('div')
    label.className = 'cursor-label absolute top-0 left-0 transform -translate-y-full text-xs text-white px-1 py-0.5 rounded whitespace-nowrap'
    label.style.backgroundColor = user.color
    label.textContent = user.name
    label.style.display = 'none'
    
    cursor.appendChild(label)
    return cursor
  }

  createCollaborativeSelection(user, selection) {
    const highlight = document.createElement('div')
    highlight.className = 'collaborative-selection absolute pointer-events-none opacity-30'
    highlight.setAttribute('data-user-selection', user.id)
    highlight.style.backgroundColor = user.color
    highlight.style.left = `${selection.start.x}px`
    highlight.style.top = `${selection.start.y}px`
    highlight.style.width = `${selection.end.x - selection.start.x}px`
    highlight.style.height = `${selection.end.y - selection.start.y}px`
    
    return highlight
  }

  // Animation methods
  addUpdateFeedback(element) {
    element.classList.add('live-update-flash')
    setTimeout(() => {
      element.classList.remove('live-update-flash')
    }, 1000)
  }

  animateElementIn(element) {
    element.style.opacity = '0'
    element.style.transform = 'translateY(-10px)'
    
    requestAnimationFrame(() => {
      element.style.transition = 'all 0.3s ease-out'
      element.style.opacity = '1'
      element.style.transform = 'translateY(0)'
    })
  }

  animateElementOut(element, callback) {
    element.style.transition = 'all 0.3s ease-in'
    element.style.opacity = '0'
    element.style.transform = 'translateY(-10px)'
    
    setTimeout(callback, 300)
  }

  showCursorName(cursor, name) {
    const label = cursor.querySelector('.cursor-label')
    if (label) {
      label.style.display = 'block'
      setTimeout(() => {
        label.style.display = 'none'
      }, 2000)
    }
  }

  showUpdateNotification(data) {
    // Simple toast notification for updates
    const toast = document.createElement('div')
    toast.className = 'toast toast-end z-40'
    toast.innerHTML = `
      <div class="alert alert-info">
        <span>📝 ${data.user?.name || 'Someone'} updated ${data.resource_type}</span>
      </div>
    `
    
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 3000)
  }

  shouldShowUpdateNotification(data) {
    // Check if user wants to see update notifications
    return this.getPreference('showUpdateNotifications', false) && 
           data.user && 
           data.user.id !== this.getCurrentUserId()
  }

  // Utility methods
  insertSorted(container, element, sortBy, value) {
    const children = Array.from(container.children).filter(child => 
      !child.hasAttribute('data-resource-template')
    )
    
    let inserted = false
    for (let child of children) {
      const childValue = child.dataset[sortBy] || child.textContent
      if (value > childValue) {
        container.insertBefore(element, child)
        inserted = true
        break
      }
    }
    
    if (!inserted) {
      container.appendChild(element)
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  getCurrentUserId() {
    // Get current user ID from meta tag or global variable
    const meta = document.querySelector('meta[name="current-user-id"]')
    return meta ? meta.content : window.currentUserId
  }

  getPreference(key, defaultValue) {
    try {
      const stored = localStorage.getItem(`liveUpdates.${key}`)
      return stored !== null ? JSON.parse(stored) : defaultValue
    } catch {
      return defaultValue
    }
  }

  // Event system
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
      this.callbacks[event].forEach(callback => callback(data))
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  // Auto-subscribe based on page content
  autoSubscribeToPageResources() {
    // Find all elements with data-resource attributes and auto-subscribe
    const resourceElements = document.querySelectorAll('[data-resource-type][data-resource-id]')
    const subscribedResources = new Set()
    
    resourceElements.forEach(element => {
      const resourceType = element.dataset.resourceType
      const resourceId = element.dataset.resourceId
      const key = `${resourceType}:${resourceId}`
      
      if (!subscribedResources.has(key)) {
        this.followResource(resourceType, resourceId)
        subscribedResources.add(key)
      }
    })
    
    // Subscribe to model lists
    const listElements = document.querySelectorAll('[data-resource-list]')
    listElements.forEach(element => {
      const modelType = element.dataset.resourceList
      this.followModel(modelType)
    })
  }
}

// Initialize live updates channel
const liveUpdatesChannel = new LiveUpdatesChannel()

// Auto-subscribe when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    liveUpdatesChannel.autoSubscribeToPageResources()
  })
} else {
  liveUpdatesChannel.autoSubscribeToPageResources()
}

// Export for use in other files
window.liveUpdatesChannel = liveUpdatesChannel

export default liveUpdatesChannel