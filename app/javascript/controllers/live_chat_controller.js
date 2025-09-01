import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["messages", "messageInput", "userCount", "usersList", "typingIndicator", "lastMessage", "lastMessageTime", "welcomeUserName"]
  static values = { 
    room: String, 
    userName: String, 
    userColor: String,
    sessionId: String 
  }
  
  connect() {
    console.log("Live chat controller connected")
    this.initializeSession()
    this.setupChannel()
    this.scrollToBottom()
  }
  
  initializeSession() {
    // Use sessionStorage to persist session ID across page refreshes
    const storageKey = `live-chat-session-${this.roomValue}`
    let sessionId = sessionStorage.getItem(storageKey)
    
    if (!sessionId) {
      // Generate new session ID if none exists
      sessionId = `guest-${Math.random().toString(36).substr(2, 16)}`
      sessionStorage.setItem(storageKey, sessionId)
    }
    
    // Override the session ID from the server with the persistent one
    this.sessionIdValue = sessionId
    
    // Update user name based on persistent session ID
    this.userNameValue = `Guest ${sessionId.substring(6, 12)}`
    
    // Generate consistent color based on session ID
    const colors = ['primary', 'secondary', 'accent', 'info', 'success', 'warning']
    const colorIndex = parseInt(sessionId.substring(6, 8), 36) % colors.length
    this.userColorValue = colors[colorIndex]
    
    console.log("Session initialized:", { sessionId, userName: this.userNameValue, color: this.userColorValue })
    
    // Update welcome message
    if (this.hasWelcomeUserNameTarget) {
      this.welcomeUserNameTarget.textContent = this.userNameValue
    }
  }
  
  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }
  
  setupChannel() {
    this.channel = consumer.subscriptions.create(
      { 
        channel: "LiveDemoChatChannel", 
        room: this.roomValue 
      },
      {
        connected: () => {
          console.log("Connected to LiveDemoChatChannel")
          this.channel.perform("join", { 
            user_name: this.userNameValue,
            session_id: this.sessionIdValue 
          })
        },
        
        disconnected: () => {
          console.log("Disconnected from LiveDemoChatChannel")
        },
        
        received: (data) => {
          console.log("Received:", data)
          
          switch(data.type) {
            case "message":
              this.appendMessage(data)
              break
            case "user_joined":
              this.handleUserJoined(data)
              break
            case "user_left":
              this.handleUserLeft(data)
              break
            case "users_list":
              this.updateUsersList(data.users)
              break
            case "typing":
              this.handleTyping(data)
              break
          }
        }
      }
    )
  }
  
  sendMessage(event) {
    event.preventDefault()
    
    const message = this.messageInputTarget.value.trim()
    if (message === "") return
    
    this.channel.perform("send_message", { 
      content: message,
      user_name: this.userNameValue,
      user_color: this.userColorValue,
      session_id: this.sessionIdValue
    })
    
    this.messageInputTarget.value = ""
    this.handleUserTyping() // Clear typing indicator
  }
  
  appendMessage(data) {
    const isOwnMessage = data.session_id === this.sessionIdValue
    console.log("Message session_id:", data.session_id, "My session_id:", this.sessionIdValue, "Is own?", isOwnMessage)
    
    const messageHtml = `
      <div class="chat ${isOwnMessage ? 'chat-end' : 'chat-start'}">
        <div class="chat-image avatar">
          <div class="w-10 rounded-full bg-${data.user_color || 'primary'} text-${data.user_color || 'primary'}-content">
            <div class="flex items-center justify-center h-full text-sm font-semibold">
              ${data.user_name.substring(0, 2).toUpperCase()}
            </div>
          </div>
        </div>
        <div class="chat-header">
          ${data.user_name}
          <time class="text-xs opacity-50">${new Date().toLocaleTimeString()}</time>
        </div>
        <div class="chat-bubble ${isOwnMessage ? `chat-bubble-${data.user_color || 'primary'}` : ''} prose prose-sm max-w-none">
          ${data.rendered_content || this.escapeHtml(data.content)}
        </div>
      </div>
    `
    
    this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
    this.scrollToBottom()
    
    // Update last message in sidebar
    this.updateLastMessage(data)
  }
  
  handleUserJoined(data) {
    const notification = `
      <div class="text-center text-sm text-success py-2">
        ${data.user_name} joined the chat
      </div>
    `
    this.messagesTarget.insertAdjacentHTML('beforeend', notification)
    this.scrollToBottom()
  }
  
  handleUserLeft(data) {
    const notification = `
      <div class="text-center text-sm text-error py-2">
        ${data.user_name} left the chat
      </div>
    `
    this.messagesTarget.insertAdjacentHTML('beforeend', notification)
    this.scrollToBottom()
  }
  
  updateUsersList(users) {
    // Update all user count displays
    this.userCountTargets.forEach(target => {
      target.textContent = users.length
    })
    
    const usersHtml = users.map(user => `
      <div class="flex items-center gap-2 p-2">
        <div class="avatar">
          <div class="w-8 rounded-full bg-${user.color || 'primary'} text-${user.color || 'primary'}-content">
            <div class="flex items-center justify-center h-full text-xs font-semibold">
              ${user.name.substring(0, 2).toUpperCase()}
            </div>
          </div>
        </div>
        <div class="text-sm flex-1">
          ${user.name}
          ${user.session_id === this.sessionIdValue ? ' <span class="text-xs opacity-50">(You)</span>' : ''}
        </div>
      </div>
    `).join('')
    
    if (this.hasUsersListTarget) {
      this.usersListTarget.innerHTML = usersHtml || '<div class="p-2 text-sm opacity-50">No users online</div>'
    }
  }
  
  handleUserTyping() {
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
    
    const isTyping = this.messageInputTarget.value.length > 0
    
    this.channel.perform("typing", { 
      is_typing: isTyping,
      user_name: this.userNameValue,
      session_id: this.sessionIdValue
    })
    
    if (isTyping) {
      this.typingTimeout = setTimeout(() => {
        this.channel.perform("typing", { 
          is_typing: false,
          user_name: this.userNameValue,
          session_id: this.sessionIdValue
        })
      }, 1000)
    }
  }
  
  handleTyping(data) {
    if (!data) return
    
    // Update typing indicators
    if (!this.typingUsers) {
      this.typingUsers = new Map()
    }
    
    if (data.is_typing && data.session_id !== this.sessionIdValue) {
      this.typingUsers.set(data.session_id, data.user_name)
    } else {
      this.typingUsers.delete(data.session_id)
    }
    
    this.updateTypingIndicator()
  }
  
  updateTypingIndicator() {
    if (!this.typingUsers || this.typingUsers.size === 0) {
      this.typingIndicatorTarget.innerHTML = ''
      return
    }
    
    const names = Array.from(this.typingUsers.values())
    let text = ''
    
    if (names.length === 1) {
      text = `${names[0]} is typing`
    } else if (names.length === 2) {
      text = `${names[0]} and ${names[1]} are typing`
    } else {
      text = `${names.length} people are typing`
    }
    
    this.typingIndicatorTarget.innerHTML = `
      <div class="text-sm text-base-content/50">
        <span class="typing-dot"></span>
        <span class="typing-dot"></span>
        <span class="typing-dot"></span>
        <span class="ml-2">${text}</span>
      </div>
    `
  }
  
  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  updateLastMessage(data) {
    if (this.hasLastMessageTarget) {
      const preview = `${data.user_name}: ${data.content.substring(0, 30)}${data.content.length > 30 ? '...' : ''}`
      this.lastMessageTarget.textContent = preview
    }
    
    if (this.hasLastMessageTimeTarget) {
      this.lastMessageTimeTarget.textContent = 'just now'
      
      // Update to relative time after a minute
      setTimeout(() => {
        if (this.hasLastMessageTimeTarget) {
          this.lastMessageTimeTarget.textContent = '1 min'
        }
      }, 60000)
    }
  }
}