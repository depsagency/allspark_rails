import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]
  
  toggleSidebar() {
    this.sidebarTarget.classList.toggle('hidden')
    this.sidebarTarget.classList.toggle('md:block')
  }
  
  createNewThread() {
    // This would trigger a modal or redirect to create a new thread
    const threadName = prompt('Enter thread name:')
    if (threadName && threadName.trim()) {
      // Make a request to create a new thread
      fetch('/chat/threads', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ 
          chat_thread: { 
            name: threadName.trim() 
          } 
        })
      })
      .then(response => response.json())
      .then(data => {
        if (data.id) {
          window.location.href = `/chat/threads/${data.id}`
        }
      })
    }
  }
}