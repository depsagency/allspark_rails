import consumer from "./consumer"

// Presence Channel for real-time user presence tracking
//
// Handles:
// - User online/offline status
// - Activity indicators
// - Typing indicators
// - User status updates
//
class PresenceChannel {
  constructor() {
    this.subscription = null
    this.onlineUsers = new Map()
    this.typingUsers = new Map()
    this.callbacks = {
      userOnline: [],
      userOffline: [],
      activityChanged: [],
      statusChanged: [],
      typingStart: [],
      typingStop: [],
      onlineUsersUpdated: []
    }
    
    this.connect()
    this.setupActivityTracking()
    
    // Set up internal event listeners
    this.on('onlineUsersUpdated', (users) => {
      this.updateOnlineUsersUI(users)
    })
  }

  connect() {
    this.subscription = consumer.subscriptions.create("PresenceChannel", {
      connected: () => {
        console.log("Connected to PresenceChannel - v2")
        this.updateActivity('active')
      },

      disconnected: () => {
        console.log("Disconnected from PresenceChannel")
      },

      received: (data) => {
        this.handlePresenceUpdate(data)
      }
    })
  }

  handlePresenceUpdate(data) {
    switch (data.type) {
      case 'user_online':
        this.handleUserOnline(data.user)
        break
        
      case 'user_offline':
        this.handleUserOffline(data.user)
        break
        
      case 'activity_changed':
        this.handleActivityChanged(data.user, data.user.activity)
        break
        
      case 'status_changed':
        this.handleStatusChanged(data.user, data.user.status_message)
        break
        
      case 'online_users':
        this.handleOnlineUsers(data.users)
        break
        
      case 'typing_start':
        this.handleTypingStart(data.user, data.context)
        break
        
      case 'typing_stop':
        this.handleTypingStop(data.user, data.context)
        break
    }
  }

  handleUserOnline(user) {
    this.onlineUsers.set(user.id, { ...user, last_seen: user.last_seen ? new Date(user.last_seen) : new Date() })
    this.updateUserPresenceUI(user, 'online')
    this.trigger('userOnline', user)
    this.trigger('onlineUsersUpdated', Array.from(this.onlineUsers.values()))
  }

  handleUserOffline(user) {
    this.onlineUsers.delete(user.id)
    this.updateUserPresenceUI(user, 'offline')
    this.trigger('userOffline', user)
    this.trigger('onlineUsersUpdated', Array.from(this.onlineUsers.values()))
  }

  handleActivityChanged(user, activity) {
    // Update the complete user data including activity and status_message
    this.onlineUsers.set(user.id, { 
      ...user, 
      last_seen: user.last_seen ? new Date(user.last_seen) : new Date() 
    })
    
    this.updateUserActivityUI(user, activity)
    this.trigger('activityChanged', { user, activity })
    // Also trigger online users updated to refresh the UI
    this.trigger('onlineUsersUpdated', Array.from(this.onlineUsers.values()))
  }

  handleStatusChanged(user, statusMessage) {
    // Update the complete user data including status_message and activity
    this.onlineUsers.set(user.id, { 
      ...user, 
      last_seen: user.last_seen ? new Date(user.last_seen) : new Date() 
    })
    
    this.updateUserStatusUI(user, statusMessage)
    this.trigger('statusChanged', { user, status_message: statusMessage })
    // Also trigger online users updated to refresh the UI
    this.trigger('onlineUsersUpdated', Array.from(this.onlineUsers.values()))
  }

  handleOnlineUsers(users) {
    this.onlineUsers.clear()
    users.forEach(user => {
      this.onlineUsers.set(user.id, user)
    })
    
    this.updateOnlineUsersUI(users)
    this.trigger('onlineUsersUpdated', users)
  }

  handleTypingStart(user, context) {
    if (!this.typingUsers.has(context)) {
      this.typingUsers.set(context, new Set())
    }
    this.typingUsers.get(context).add(user.id)
    
    this.updateTypingIndicator(context)
    this.trigger('typingStart', { user, context })
  }

  handleTypingStop(user, context) {
    if (this.typingUsers.has(context)) {
      this.typingUsers.get(context).delete(user.id)
      if (this.typingUsers.get(context).size === 0) {
        this.typingUsers.delete(context)
      }
    }
    
    this.updateTypingIndicator(context)
    this.trigger('typingStop', { user, context })
  }

  // UI update methods
  updateUserPresenceUI(user, status) {
    const elements = document.querySelectorAll(`[data-user-id="${user.id}"]`)
    elements.forEach(element => {
      const indicator = element.querySelector('.presence-indicator')
      if (indicator) {
        indicator.className = `presence-indicator ${this.getPresenceClass(status)}`
        indicator.title = `${user.name} is ${status}`
      }
    })
  }

  updateUserActivityUI(user, activity) {
    const elements = document.querySelectorAll(`[data-user-id="${user.id}"]`)
    elements.forEach(element => {
      const indicator = element.querySelector('.activity-indicator')
      if (indicator) {
        indicator.className = `activity-indicator ${this.getActivityClass(activity)}`
        indicator.title = `${user.name} is ${activity}`
      }
    })
  }

  updateUserStatusUI(user, statusMessage) {
    const elements = document.querySelectorAll(`[data-user-id="${user.id}"]`)
    elements.forEach(element => {
      const statusElement = element.querySelector('.user-status')
      if (statusElement) {
        statusElement.textContent = statusMessage || ''
        statusElement.style.display = statusMessage ? 'block' : 'none'
      }
    })
  }

  updateOnlineUsersUI(users) {
    console.log('Updating online users UI with:', users)
    const container = document.querySelector('#online-users-list')
    if (!container) return
    
    container.innerHTML = ''
    
    users.forEach(user => {
      const userElement = this.createUserElement(user)
      container.appendChild(userElement)
    })
    
    // Update online count
    const countElement = document.querySelector('#online-users-count')
    if (countElement) {
      countElement.textContent = users.length
    }
  }

  updateTypingIndicator(context) {
    const indicator = document.querySelector(`[data-typing-context="${context}"]`)
    if (!indicator) return
    
    const typingUserIds = this.typingUsers.get(context)
    
    if (!typingUserIds || typingUserIds.size === 0) {
      indicator.style.display = 'none'
      return
    }
    
    const typingUserNames = Array.from(typingUserIds)
      .map(id => this.onlineUsers.get(id)?.name)
      .filter(name => name)
    
    if (typingUserNames.length === 0) {
      indicator.style.display = 'none'
      return
    }
    
    let text
    if (typingUserNames.length === 1) {
      text = `${typingUserNames[0]} is typing...`
    } else if (typingUserNames.length === 2) {
      text = `${typingUserNames[0]} and ${typingUserNames[1]} are typing...`
    } else {
      text = `${typingUserNames.length} people are typing...`
    }
    
    indicator.textContent = text
    indicator.style.display = 'block'
  }

  createUserElement(user) {
    console.log('Creating user element for:', user.name, 'with data:', user)
    const element = document.createElement('div')
    element.className = 'flex items-center gap-2 p-2 hover:bg-base-200 rounded'
    element.setAttribute('data-user-id', user.id)
    
    element.innerHTML = `
      <div class="relative">
        ${user.avatar_url ? 
          `<img src="${user.avatar_url}" class="w-8 h-8 rounded-full" alt="${this.escapeHtml(user.name)}">` :
          `<div class="w-8 h-8 rounded-full bg-primary text-primary-content text-xs flex items-center justify-center">${user.name.charAt(0)}</div>`
        }
        <div class="presence-indicator ${this.getPresenceClass('online')} absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-base-100"></div>
      </div>
      <div class="flex-1 min-w-0">
        <div class="font-medium text-sm truncate">${this.escapeHtml(user.name)}</div>
        <div class="text-xs text-base-content/60 flex items-center gap-1">
          <span class="activity-indicator ${this.getActivityClass(user.activity)}">${this.getActivityText(user.activity)}</span>
          ${user.last_seen ? `• ${this.formatLastSeen(user.last_seen)}` : ''}
        </div>
        ${user.status_message ? `<div class="user-status text-xs text-base-content/80 mt-1">${this.escapeHtml(user.status_message)}</div>` : ''}
      </div>
    `
    
    return element
  }

  // Action methods
  updateActivity(activity) {
    console.log('updateActivity called:', activity, 'subscription:', !!this.subscription)
    if (this.subscription && ['active', 'away', 'busy'].includes(activity)) {
      console.log('Performing update_activity with:', { activity })
      this.subscription.perform('update_activity', { activity })
    } else {
      console.log('Cannot update activity:', {
        hasSubscription: !!this.subscription,
        validActivity: ['active', 'away', 'busy'].includes(activity)
      })
    }
  }

  updateStatus(statusMessage) {
    console.log('updateStatus called:', statusMessage, 'subscription:', !!this.subscription)
    if (this.subscription) {
      console.log('Performing update_status with:', { status_message: statusMessage })
      this.subscription.perform('update_status', { status_message: statusMessage })
    } else {
      console.log('Cannot update status: no subscription')
    }
  }

  startTyping(context) {
    if (this.subscription && context) {
      this.subscription.perform('start_typing', { context })
    }
  }

  stopTyping(context) {
    if (this.subscription && context) {
      this.subscription.perform('stop_typing', { context })
    }
  }

  // Setup automatic activity tracking
  setupActivityTracking() {
    let activityTimer
    let isAway = false
    
    const resetActivity = () => {
      if (isAway) {
        isAway = false
        this.updateActivity('active')
      }
      
      clearTimeout(activityTimer)
      activityTimer = setTimeout(() => {
        isAway = true
        this.updateActivity('away')
      }, 5 * 60 * 1000) // 5 minutes
    }
    
    // Track user activity
    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart']
    events.forEach(event => {
      document.addEventListener(event, resetActivity, { passive: true })
    })
    
    // Track page visibility
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.updateActivity('away')
      } else {
        resetActivity()
      }
    })
    
    // Initial activity tracking
    resetActivity()
  }

  // Utility methods
  getPresenceClass(status) {
    switch (status) {
      case 'online': return 'bg-success'
      case 'away': return 'bg-warning'
      case 'busy': return 'bg-error'
      case 'offline': return 'bg-base-300'
      default: return 'bg-base-300'
    }
  }

  getActivityClass(activity) {
    switch (activity) {
      case 'active': return 'text-success'
      case 'away': return 'text-warning'
      case 'busy': return 'text-error'
      default: return 'text-base-content/60'
    }
  }

  getActivityText(activity) {
    switch (activity) {
      case 'active': return 'Active'
      case 'away': return 'Away'
      case 'busy': return 'Busy'
      default: return 'Unknown'
    }
  }

  formatLastSeen(lastSeen) {
    const date = new Date(lastSeen)
    const now = new Date()
    const diff = now - date
    
    if (diff < 60000) { // Less than 1 minute
      return 'Just now'
    } else if (diff < 3600000) { // Less than 1 hour
      const minutes = Math.floor(diff / 60000)
      return `${minutes}m ago`
    } else if (diff < 86400000) { // Less than 1 day
      const hours = Math.floor(diff / 3600000)
      return `${hours}h ago`
    } else {
      return date.toLocaleDateString()
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
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

  // Public getters
  getOnlineUsers() {
    return Array.from(this.onlineUsers.values())
  }

  getTypingUsers(context) {
    const typingUserIds = this.typingUsers.get(context)
    if (!typingUserIds) return []
    
    return Array.from(typingUserIds)
      .map(id => this.onlineUsers.get(id))
      .filter(user => user)
  }

  isUserOnline(userId) {
    return this.onlineUsers.has(userId)
  }
}

// Initialize presence channel
const presenceChannel = new PresenceChannel()

// Export for use in other files
window.presenceChannel = presenceChannel

// Debug: Log that presence channel is available
console.log('Presence channel methods available:', {
  updateActivity: typeof presenceChannel.updateActivity,
  updateStatus: typeof presenceChannel.updateStatus
})

export default presenceChannel