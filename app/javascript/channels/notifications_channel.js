import consumer from "./consumer"

// Notifications Channel for real-time notifications
//
// Handles:
// - Receiving new notifications
// - Updating notification counters
// - Managing notification state
//
class NotificationsChannel {
  constructor() {
    this.subscription = null
    this.callbacks = {
      notification: [],
      unreadCount: [],
      connected: [],
      disconnected: []
    }
    
    this.connect()
  }

  connect() {
    this.subscription = consumer.subscriptions.create("NotificationsChannel", {
      connected: () => {
        console.log("Connected to NotificationsChannel")
        this.trigger('connected')
      },

      disconnected: () => {
        console.log("Disconnected from NotificationsChannel")
        this.trigger('disconnected')
      },

      received: (data) => {
        this.handleNotification(data)
      }
    })
  }

  handleNotification(data) {
    switch (data.type) {
      case 'new_notification':
        this.handleNewNotification(data.notification)
        this.updateUnreadCount(data.unread_count)
        break
        
      case 'notification_updated':
        this.handleNotificationUpdate(data)
        this.updateUnreadCount(data.unread_count)
        break
        
      case 'unread_count':
        this.updateUnreadCount(data.count)
        break
        
      case 'marked_as_read':
        this.handleMarkAsRead(data.notification_id)
        this.updateUnreadCount(data.unread_count)
        break
        
      case 'all_marked_as_read':
        this.handleMarkAllAsRead()
        this.updateUnreadCount(0)
        break
        
      case 'recent_notifications':
        this.handleRecentNotifications(data.notifications)
        break
    }
  }

  handleNewNotification(notification) {
    // Show toast notification
    this.showToast(notification)
    
    // Update notification UI
    this.addNotificationToUI(notification)
    
    // Trigger callbacks
    this.trigger('notification', notification)
    
    // Play sound if enabled
    this.playNotificationSound()
  }

  handleNotificationUpdate(data) {
    // Update notification in UI
    const element = document.querySelector(`[data-notification-id="${data.notification_id}"]`)
    if (element) {
      if (data.read) {
        element.classList.add('read')
        element.classList.remove('unread')
      } else {
        element.classList.add('unread')
        element.classList.remove('read')
      }
    }
  }

  handleMarkAsRead(notificationId) {
    const element = document.querySelector(`[data-notification-id="${notificationId}"]`)
    if (element) {
      element.classList.add('read')
      element.classList.remove('unread')
    }
  }

  handleMarkAllAsRead() {
    const elements = document.querySelectorAll('[data-notification-id]')
    elements.forEach(el => {
      el.classList.add('read')
      el.classList.remove('unread')
    })
  }

  handleRecentNotifications(notifications) {
    // Clear current notifications
    const container = document.querySelector('#notifications-list')
    if (container) {
      container.innerHTML = ''
      
      // Add each notification
      notifications.forEach(notification => {
        this.addNotificationToUI(notification, container)
      })
    }
  }

  updateUnreadCount(count) {
    // Update badge counters
    const badges = document.querySelectorAll('[data-notification-count]')
    badges.forEach(badge => {
      badge.textContent = count
      badge.style.display = count > 0 ? 'inline' : 'none'
    })
    
    // Update document title
    if (count > 0) {
      const baseTitle = document.title.replace(/^\(\d+\)\s/, '')
      document.title = `(${count}) ${baseTitle}`
    } else {
      document.title = document.title.replace(/^\(\d+\)\s/, '')
    }
    
    // Trigger callback
    this.trigger('unreadCount', count)
  }

  showToast(notification) {
    console.log('Showing toast for notification:', notification)
    // Check if user wants to see toast notifications
    if (this.shouldShowToast()) {
      const toast = this.createToastElement(notification)
      document.body.appendChild(toast)
      console.log('Toast element added to DOM')
      
      // Auto-remove after 5 seconds
      setTimeout(() => {
        console.log('Removing toast after 5 seconds')
        if (toast.parentNode) {
          toast.remove()
        }
      }, 5000)
    } else {
      console.log('Toast notifications disabled or document hidden')
    }
  }

  createToastElement(notification) {
    const toast = document.createElement('div')
    toast.className = 'toast toast-end z-50'
    toast.style.cssText = 'position: fixed; bottom: 1rem; right: 1rem;' // Ensure proper positioning
    toast.innerHTML = `
      <div class="alert alert-${notification.type || 'info'} shadow-lg max-w-sm cursor-pointer" 
           onclick="this.parentNode.remove()">
        <div class="flex">
          <span class="text-lg">${notification.icon || '📢'}</span>
          <div class="flex-1 ml-2">
            <div class="font-semibold">${this.escapeHtml(notification.title)}</div>
            <div class="text-sm opacity-90">${this.escapeHtml(notification.message)}</div>
          </div>
          <button class="btn btn-ghost btn-xs" onclick="event.stopPropagation(); this.closest('.toast').remove()">
            ✕
          </button>
        </div>
      </div>
    `
    return toast
  }

  addNotificationToUI(notification, container = null) {
    const targetContainer = container || document.querySelector('#notifications-list')
    if (!targetContainer) return
    
    const element = document.createElement('div')
    element.className = `notification-item p-3 border-b border-base-300 hover:bg-base-200 cursor-pointer ${notification.read ? 'read opacity-75' : 'unread'}`
    element.setAttribute('data-notification-id', notification.id)
    
    element.innerHTML = `
      <div class="flex items-start gap-3">
        <span class="text-lg flex-shrink-0">${notification.icon}</span>
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between gap-2">
            <h4 class="font-medium text-sm leading-tight">${this.escapeHtml(notification.title)}</h4>
            <span class="text-xs text-base-content/60 flex-shrink-0">${notification.time_ago}</span>
          </div>
          <p class="text-sm text-base-content/80 mt-1">${this.escapeHtml(notification.message)}</p>
          ${notification.sender ? `
            <div class="flex items-center gap-2 mt-2">
              ${notification.sender.avatar_url ? 
                `<img src="${notification.sender.avatar_url}" class="w-4 h-4 rounded-full">` :
                `<div class="w-4 h-4 rounded-full bg-primary text-primary-content text-xs flex items-center justify-center">${notification.sender.name.charAt(0)}</div>`
              }
              <span class="text-xs text-base-content/60">${this.escapeHtml(notification.sender.name)}</span>
            </div>
          ` : ''}
        </div>
        ${!notification.read ? '<div class="w-2 h-2 bg-primary rounded-full flex-shrink-0 mt-2"></div>' : ''}
      </div>
    `
    
    // Add click handler
    element.addEventListener('click', () => {
      this.markAsRead(notification.id)
      if (notification.action_url) {
        window.location.href = notification.action_url
      }
    })
    
    // Insert at the top
    targetContainer.insertBefore(element, targetContainer.firstChild)
  }

  shouldShowToast() {
    // Check user preferences or document visibility
    return !document.hidden && this.getPreference('showToasts', true)
  }

  playNotificationSound() {
    if (this.getPreference('playSound', false)) {
      // Create and play a subtle notification sound
      const audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+L0u2QZBS2O1+/QfS4IHHDK8+GGMG4/ltBuAAAAA==')
      audio.volume = 0.3
      audio.play().catch(() => {
        // Ignore autoplay restrictions
      })
    }
  }

  markAsRead(notificationId) {
    if (this.subscription) {
      this.subscription.perform('mark_as_read', { notification_id: notificationId })
    }
  }

  markAllAsRead() {
    if (this.subscription) {
      this.subscription.perform('mark_all_as_read')
    }
  }

  getRecentNotifications(limit = 20) {
    if (this.subscription) {
      this.subscription.perform('get_recent_notifications', { limit: limit })
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

  // Utility methods
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  getPreference(key, defaultValue) {
    try {
      const stored = localStorage.getItem(`notifications.${key}`)
      return stored !== null ? JSON.parse(stored) : defaultValue
    } catch {
      return defaultValue
    }
  }

  setPreference(key, value) {
    try {
      localStorage.setItem(`notifications.${key}`, JSON.stringify(value))
    } catch {
      // Ignore storage errors
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }
}

// Initialize notifications channel
const notificationsChannel = new NotificationsChannel()

// Export for use in other files
window.notificationsChannel = notificationsChannel

export default notificationsChannel