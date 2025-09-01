import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["messagesContainer", "messageInput", "typingIndicator", "typingText"]
  static values = { 
    threadId: Number,
    userId: String,
    userName: String
  }
  
  connect() {
    console.log("Chat controller connecting with userId:", this.userIdValue, "userName:", this.userNameValue)
    this.setupChannel()
    this.scrollToBottom()
    this.typingUsers = new Map()
    this.typingTimeout = null
  }
  
  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }
  
  setupChannel() {
    console.log("Setting up ChatChannel for thread:", this.threadIdValue)
    
    this.channel = consumer.subscriptions.create(
      { 
        channel: "ChatChannel", 
        thread_id: this.threadIdValue 
      },
      {
        connected: () => {
          console.log("Connected to ChatChannel for thread:", this.threadIdValue)
          this.markAsRead()
        },
        
        disconnected: () => {
          console.log("Disconnected from ChatChannel")
        },
        
        received: (data) => {
          console.log("Received data:", data)
          this.handleReceivedData(data)
        },
        
        rejected: () => {
          console.error("Subscription rejected!")
        }
      }
    )
    
    // Store reference for debugging
    window.chatChannel = this.channel
  }
  
  handleReceivedData(data) {
    switch(data.type) {
      case 'new_message':
        this.appendMessage(data.message)
        this.markAsRead()
        break
      case 'message_updated':
        this.updateMessage(data.message)
        break
      case 'message_deleted':
        this.removeMessage(data.message_id)
        break
      case 'typing':
        this.handleTypingIndicator(data)
        break
      case 'user_joined':
        this.showNotification(`${data.user.name} joined the conversation`)
        break
      case 'user_left':
        this.showNotification(`${data.user.name} left the conversation`)
        break
      case 'read_receipt':
        this.updateReadReceipt(data)
        break
    }
  }
  
  sendMessage(event) {
    event.preventDefault()
    
    const content = this.messageInputTarget.value.trim()
    if (!content) return
    
    console.log("Sending message:", content)
    
    if (!this.channel) {
      console.error("Channel not initialized!")
      return
    }
    
    // Perform the action
    const result = this.channel.perform('send_message', { content: content })
    console.log("Perform result:", result)
    
    this.messageInputTarget.value = ''
    this.handleTyping() // Clear typing indicator
  }
  
  editMessage(event) {
    event.preventDefault()
    const messageId = event.currentTarget.dataset.messageId
    const messageElement = document.querySelector(`[data-message-id="${messageId}"]`)
    const contentElement = messageElement.querySelector('.chat-bubble p')
    
    const newContent = prompt('Edit message:', contentElement.textContent)
    if (newContent && newContent.trim()) {
      this.channel.perform('edit_message', { 
        message_id: messageId, 
        content: newContent.trim() 
      })
    }
  }
  
  deleteMessage(event) {
    event.preventDefault()
    const messageId = event.currentTarget.dataset.messageId
    
    if (confirm('Are you sure you want to delete this message?')) {
      this.channel.perform('delete_message', { message_id: messageId })
    }
  }
  
  handleTyping() {
    const isTyping = this.messageInputTarget.value.length > 0
    
    // Throttle typing events
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
    
    this.channel.perform('typing', { is_typing: isTyping })
    
    if (isTyping) {
      this.typingTimeout = setTimeout(() => {
        this.channel.perform('typing', { is_typing: false })
      }, 3000)
    }
  }
  
  markAsRead() {
    this.channel.perform('mark_as_read')
  }
  
  appendMessage(message) {
    const messageHtml = this.renderMessage(message)
    this.messagesContainerTarget.insertAdjacentHTML('beforeend', messageHtml)
    this.scrollToBottom()
  }
  
  updateMessage(message) {
    const messageElement = document.querySelector(`[data-message-id="${message.id}"]`)
    if (messageElement) {
      const contentElement = messageElement.querySelector('.chat-bubble p')
      contentElement.textContent = message.content
      
      // Update edited indicator
      const timeElement = messageElement.querySelector('.text-xs')
      if (message.edited && !timeElement.textContent.includes('(edited)')) {
        timeElement.insertAdjacentHTML('beforeend', ' <span class="opacity-70">(edited)</span>')
      }
    }
  }
  
  removeMessage(messageId) {
    const messageElement = document.querySelector(`[data-message-id="${messageId}"]`)
    if (messageElement) {
      messageElement.remove()
    }
  }
  
  handleTypingIndicator(data) {
    if (data.user.id === this.userIdValue) return
    
    if (data.is_typing) {
      this.typingUsers.set(data.user.id, data.user.name)
    } else {
      this.typingUsers.delete(data.user.id)
    }
    
    this.updateTypingIndicator()
  }
  
  updateTypingIndicator() {
    if (this.typingUsers.size === 0) {
      this.typingIndicatorTarget.style.display = 'none'
      return
    }
    
    const names = Array.from(this.typingUsers.values())
    let text = ''
    
    if (names.length === 1) {
      text = `${names[0]} is typing...`
    } else if (names.length === 2) {
      text = `${names[0]} and ${names[1]} are typing...`
    } else {
      text = `${names.length} people are typing...`
    }
    
    this.typingTextTarget.textContent = text
    this.typingIndicatorTarget.style.display = 'block'
  }
  
  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }
  
  showNotification(message) {
    // Create a temporary notification in the chat
    const notificationHtml = `
      <div class="text-center py-2 text-sm text-base-content/50">
        ${message}
      </div>
    `
    this.messagesContainerTarget.insertAdjacentHTML('beforeend', notificationHtml)
    this.scrollToBottom()
  }
  
  updateReadReceipt(data) {
    // This could be enhanced to show read receipts on messages
    console.log('Read receipt:', data)
  }
  
  renderMessage(message) {
    const isOwn = message.user_id === this.userIdValue
    console.log("Rendering message - message.user_id:", message.user_id, "this.userIdValue:", this.userIdValue, "isOwn:", isOwn, "Type of message.user_id:", typeof message.user_id, "Type of this.userIdValue:", typeof this.userIdValue)
    const chatClass = isOwn ? 'chat-end' : 'chat-start'
    const bubbleClass = isOwn ? 'chat-bubble-primary' : ''
    
    const time = new Date(message.created_at).toLocaleTimeString('en-US', { 
      hour: 'numeric', 
      minute: '2-digit' 
    })
    
    const avatarColor = isOwn ? 'bg-primary text-primary-content' : 'bg-neutral text-neutral-content'
    const initials = this.getInitials(isOwn ? this.userNameValue : message.user_name)
    
    return `
      <div class="chat ${chatClass}" data-message-id="${message.id}" data-user-id="${message.user_id}">
        <div class="chat-image avatar">
          <div class="w-10 h-10 rounded-full ${avatarColor}">
            <div class="flex items-center justify-center h-full text-sm font-semibold">
              ${initials}
            </div>
          </div>
        </div>
        
        <div class="chat-header">
          ${message.user_name}
          <time class="text-xs opacity-50">${time}</time>
        </div>
        
        <div class="chat-bubble ${bubbleClass}">
          ${this.escapeHtml(message.content)}
        </div>
        
        <div class="chat-footer opacity-50">
          ${message.edited ? '<span class="text-xs">Edited</span>' : ''}
          
          ${isOwn ? `
            <div class="dropdown dropdown-top dropdown-end">
              <label tabindex="0" class="btn btn-ghost btn-xs">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM12.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM18.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0z" />
                </svg>
              </label>
              <ul tabindex="0" class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-32">
                <li>
                  <a data-action="click->chat#editMessage" data-message-id="${message.id}">
                    Edit
                  </a>
                </li>
                <li>
                  <a data-action="click->chat#deleteMessage" data-message-id="${message.id}" class="text-error">
                    Delete
                  </a>
                </li>
              </ul>
            </div>
          ` : ''}
        </div>
      </div>
    `
  }
  
  getInitials(name) {
    const parts = name.split(' ')
    if (parts.length >= 2) {
      return parts[0][0] + parts[1][0]
    }
    return name.substring(0, 2).toUpperCase()
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  selectThread(event) {
    const threadId = event.currentTarget.dataset.threadId
    // This would typically trigger a page navigation or update the current thread
    window.location.href = `/chat/threads/${threadId}`
  }
}