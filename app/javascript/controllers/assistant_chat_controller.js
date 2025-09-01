import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "typingIndicator"]
  static values = { 
    assistantId: String,
    userId: String
  }

  connect() {
    console.log("AssistantChatController connected", {
      assistantId: this.assistantIdValue,
      userId: this.userIdValue,
      element: this.element,
      hasTargets: {
        messages: this.hasMessagesTarget,
        input: this.hasInputTarget,
        sendButton: this.hasSendButtonTarget,
        typingIndicator: this.hasTypingIndicatorTarget
      },
      targets: {
        messagesTarget: this.messagesTarget,
        inputTarget: this.inputTarget
      }
    })
    this.setupSubscription()
    
    // Only scroll to bottom if there are messages
    if (this.hasMessagesTarget && this.messagesTarget.children.length > 0) {
      // Use setTimeout to ensure DOM is fully rendered
      setTimeout(() => {
        this.scrollToBottom()
      }, 100)
    }
  }

  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  setupSubscription() {
    this.channel = consumer.subscriptions.create(
      {
        channel: "AssistantChannel",
        assistant_id: this.assistantIdValue
      },
      {
        connected: () => {
          console.log("Connected to AssistantChannel")
        },

        disconnected: () => {
          console.log("Disconnected from AssistantChannel")
        },

        received: (data) => {
          this.handleMessage(data)
        }
      }
    )
  }

  handleMessage(data) {
    console.log('Received message:', data.type, data)
    switch(data.type) {
      case 'user_message':
        // Skip user messages from broadcasts - they're already in the UI
        break
      case 'user_message_saved':
        // Update the temporary user message with the real one from database
        this.updateUserMessage(data.run_id, data.message)
        break
      case 'assistant_start':
        console.log('Starting assistant response')
        this.showTypingIndicator()
        break
      case 'assistant_chunk':
        console.log('Received chunk:', data.chunk)
        this.appendChunk(data.chunk, data.run_id)
        break
      case 'assistant_complete':
        // Skip complete messages - we only use streaming
        console.log('Assistant complete')
        this.hideTypingIndicator()
        break
      case 'assistant_stream_complete':
        console.log('Stream complete')
        this.hideTypingIndicator()
        this.finalizeStreamingMessage(data.run_id, data.formatted_content)
        break
      case 'assistant_error':
        console.log('Assistant error:', data.error)
        this.hideTypingIndicator()
        this.showError(data.error)
        break
      case 'typing':
        this.handleTypingIndicator(data)
        break
    }
  }

  sendMessage(event) {
    event.preventDefault()
    console.log("sendMessage called")
    
    const message = this.inputTarget.value.trim()
    if (!message) return

    console.log("Sending message:", message)
    console.log("Messages target exists:", !!this.messagesTarget)

    const runId = this.generateRunId()

    // Clear input immediately
    this.inputTarget.value = ""

    // Add user message to UI immediately
    const tempId = `temp_${Date.now()}`
    const messageHtml = `
      <div class="chat chat-end" data-message-id="${tempId}" data-run-id="${runId}">
        <div class="chat-image avatar">
          <div class="w-10 rounded-full bg-base-300">
            <div class="flex items-center justify-center h-10 text-sm font-semibold">
              U
            </div>
          </div>
        </div>
        <div class="chat-header">
          User
          <time class="text-xs opacity-50">${new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}</time>
        </div>
        <div class="chat-bubble chat-bubble-primary">
          <div class="prose prose-sm max-w-none">
            ${message.replace(/</g, '&lt;').replace(/>/g, '&gt;')}
          </div>
        </div>
      </div>
    `
    
    // Insert message before typing indicator if it exists
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.insertAdjacentHTML('beforebegin', messageHtml)
    } else {
      this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
    }
    this.scrollToBottom()
    console.log("Message added to DOM")

    // Send via channel
    if (this.channel) {
      this.channel.perform('send_message', {
        message: message,
        run_id: runId
      })
      console.log("Message sent to channel")
    } else {
      console.error("No channel available")
    }
    
    // Re-enable and focus input
    this.inputTarget.focus()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  appendMessage(message) {
    console.log('appendMessage called with:', message)
    
    // Check if message already exists in the DOM
    if (message.id && this.messagesTarget.querySelector(`[data-message-id="${message.id}"]`)) {
      console.log("Message already exists, skipping:", message.id)
      return
    }
    
    const messageHtml = this.buildMessageHtml(message)
    console.log('Built message HTML:', messageHtml)
    
    // Insert message before typing indicator if it exists
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.insertAdjacentHTML('beforebegin', messageHtml)
    } else {
      this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
    }
    this.scrollToBottom()
  }

  appendChunk(chunk, runId) {
    console.log('appendChunk called with:', chunk, runId)
    
    // Hide typing indicator when first chunk arrives
    this.hideTypingIndicator()
    
    // Find or create streaming message
    let streamingMsg = this.messagesTarget.querySelector(`[data-run-id="${runId}"]`)
    
    if (!streamingMsg) {
      // Create new streaming message
      const messageHtml = this.buildStreamingMessageHtml(runId)
      
      // Insert before typing indicator if it exists
      if (this.hasTypingIndicatorTarget) {
        this.typingIndicatorTarget.insertAdjacentHTML('beforebegin', messageHtml)
      } else {
        this.messagesTarget.insertAdjacentHTML('beforeend', messageHtml)
      }
      streamingMsg = this.messagesTarget.querySelector(`[data-run-id="${runId}"]`)
    }
    
    // Append chunk to content
    const contentEl = streamingMsg.querySelector('.streaming-content')
    if (contentEl) {
      contentEl.textContent += chunk
    } else {
      console.error('Could not find streaming-content element')
    }
    this.scrollToBottom()
  }

  finalizeStreamingMessage(runId, formattedContent) {
    // Convert streaming message to final message
    const streamingMsg = this.messagesTarget.querySelector(`[data-run-id="${runId}"]`)
    if (streamingMsg) {
      // Remove the data-run-id and add a proper message ID to prevent duplicates
      streamingMsg.removeAttribute('data-run-id')
      streamingMsg.setAttribute('data-message-id', `assistant_${runId}`)
      
      // Replace content with server-rendered markdown if provided
      if (formattedContent) {
        const contentEl = streamingMsg.querySelector('.streaming-content')
        if (contentEl) {
          // Replace the streaming-content class with prose for markdown rendering
          contentEl.className = 'prose prose-sm max-w-none'
          contentEl.innerHTML = formattedContent
        }
      }
    }
  }

  buildMessageHtml(message) {
    const isUser = message.role === 'user'
    const isCurrentUser = isUser && message.metadata?.user_id === this.userIdValue
    const position = isCurrentUser ? 'chat-end' : 'chat-start'
    const bubbleColor = this.getBubbleColor(message.role, isCurrentUser)
    
    return `
      <div class="chat ${position}" data-message-id="${message.id}">
        <div class="chat-image avatar">
          <div class="w-10 rounded-full bg-base-300">
            <div class="flex items-center justify-center h-10 text-sm font-semibold">
              ${this.getInitials(message)}
            </div>
          </div>
        </div>
        <div class="chat-header">
          ${this.getDisplayName(message)}
          <time class="text-xs opacity-50">${this.formatTime(message.created_at)}</time>
        </div>
        <div class="chat-bubble ${bubbleColor}">
          <div class="prose prose-sm max-w-none">
            ${this.formatContent(message.content, message.role)}
          </div>
        </div>
      </div>
    `
  }

  buildStreamingMessageHtml(runId) {
    return `
      <div class="chat chat-start" data-run-id="${runId}">
        <div class="chat-image avatar">
          <div class="w-10 rounded-full bg-base-300">
            <div class="flex items-center justify-center h-10 text-sm font-semibold">
              AI
            </div>
          </div>
        </div>
        <div class="chat-header">
          AI Assistant
          <time class="text-xs opacity-50">${this.formatTime(new Date())}</time>
        </div>
        <div class="chat-bubble chat-bubble-secondary">
          <div class="prose prose-sm max-w-none streaming-content"></div>
        </div>
      </div>
    `
  }

  showTypingIndicator() {
    console.log('Showing typing indicator')
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove('hidden')
      this.scrollToBottom()
    }
  }

  hideTypingIndicator() {
    console.log('Hiding typing indicator')
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.add('hidden')
    }
  }

  showError(error) {
    const errorHtml = `
      <div class="alert alert-error mb-4">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span>Error: ${error}</span>
      </div>
    `
    // Insert error before typing indicator if it exists
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.insertAdjacentHTML('beforebegin', errorHtml)
    } else {
      this.messagesTarget.insertAdjacentHTML('beforeend', errorHtml)
    }
    this.scrollToBottom()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  generateRunId() {
    return `run_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  getBubbleColor(role, isCurrentUser) {
    switch(role) {
      case 'user':
        return isCurrentUser ? 'chat-bubble-primary' : 'chat-bubble'
      case 'assistant':
        return 'chat-bubble-secondary'
      case 'system':
        return 'chat-bubble-info'
      case 'tool':
        return 'chat-bubble-accent'
      default:
        return 'chat-bubble'
    }
  }

  getInitials(message) {
    if (message.role === 'assistant') return 'AI'
    if (message.role === 'system') return 'S'
    if (message.role === 'tool') return 'T'
    return 'U'
  }

  getDisplayName(message) {
    if (message.role === 'assistant') return 'AI Assistant'
    if (message.role === 'system') return 'System'
    if (message.role === 'tool') return 'Tool'
    return 'User'
  }

  formatTime(timestamp) {
    const date = new Date(timestamp)
    return date.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
  }

  formatContent(content, role) {
    // For user messages and during streaming, just escape HTML and convert line breaks
    const escaped = content
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
    
    return escaped.replace(/\n/g, '<br>')
  }

  updateUserMessage(runId, message) {
    // Find the temporary message by run-id and update it with the real message data
    const tempMessage = this.messagesTarget.querySelector(`[data-run-id="${runId}"]`)
    if (tempMessage) {
      // Update the message ID and remove the run-id
      tempMessage.setAttribute('data-message-id', message.id)
      tempMessage.removeAttribute('data-run-id')
    }
  }
  
}