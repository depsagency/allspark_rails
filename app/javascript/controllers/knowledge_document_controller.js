import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["status", "message", "chunksCount", "spinner", "processButton", "content"]
  
  connect() {
    this.documentId = this.data.get("id")
    
    if (!this.documentId) return
    
    // Create subscription to knowledge document channel
    this.subscription = consumer.subscriptions.create(
      { 
        channel: "KnowledgeDocumentChannel", 
        document_id: this.documentId 
      },
      {
        connected: () => {
          console.log("Connected to KnowledgeDocumentChannel")
        },
        
        disconnected: () => {
          console.log("Disconnected from KnowledgeDocumentChannel")
        },
        
        received: (data) => {
          this.handleUpdate(data)
        }
      }
    )
  }
  
  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
  
  handleUpdate(data) {
    console.log("Received update:", data)
    
    switch(data.type) {
      case "connected":
        this.updateStatus(data.status)
        if (data.chunks_count > 0) {
          this.updateChunksCount(data.chunks_count)
        }
        break
        
      case "update":
        this.showMessage(data.message, "info")
        this.updateStatus(data.status)
        if (data.chunks_count > 0) {
          this.updateChunksCount(data.chunks_count)
        }
        if (data.status === "completed") {
          this.handleCompletion()
        }
        break
        
      case "error":
        this.showMessage(data.message, "error")
        this.updateStatus("error")
        this.hideSpinner()
        break
    }
  }
  
  updateStatus(status) {
    if (this.hasStatusTarget) {
      // Update status badge
      const statusBadge = this.statusTarget
      statusBadge.textContent = this.formatStatus(status)
      
      // Update badge color
      statusBadge.classList.remove("badge-info", "badge-success", "badge-error", "badge-warning")
      switch(status) {
        case "processing":
          statusBadge.classList.add("badge-info")
          this.showSpinner()
          break
        case "completed":
          statusBadge.classList.add("badge-success")
          this.hideSpinner()
          break
        case "error":
          statusBadge.classList.add("badge-error")
          this.hideSpinner()
          break
        default:
          statusBadge.classList.add("badge-warning")
      }
    }
  }
  
  updateChunksCount(count) {
    if (this.hasChunksCountTarget) {
      this.chunksCountTarget.textContent = `${count} chunks`
    }
  }
  
  showMessage(message, type = "info") {
    if (this.hasMessageTarget) {
      const messageEl = this.messageTarget
      messageEl.textContent = message
      messageEl.classList.remove("hidden", "text-info", "text-success", "text-error")
      
      switch(type) {
        case "info":
          messageEl.classList.add("text-info")
          break
        case "success":
          messageEl.classList.add("text-success")
          break
        case "error":
          messageEl.classList.add("text-error")
          break
      }
      
      // Auto-hide message after 5 seconds
      setTimeout(() => {
        messageEl.classList.add("hidden")
      }, 5000)
    }
  }
  
  showSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
  }
  
  hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden")
    }
  }
  
  handleCompletion() {
    // Hide process button if it exists
    if (this.hasProcessButtonTarget) {
      this.processButtonTarget.classList.add("hidden")
    }
    
    // Show success message
    this.showMessage("Document processed successfully! Refreshing page...", "success")
    
    // Refresh the page after a short delay to show the processed content
    setTimeout(() => {
      window.location.reload()
    }, 2000)
  }
  
  formatStatus(status) {
    return status.charAt(0).toUpperCase() + status.slice(1)
  }
}