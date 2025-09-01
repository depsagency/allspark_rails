import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["refreshButton", "exportButton"]

  connect() {
    this.setupAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  setupAutoRefresh() {
    // Auto-refresh every 30 seconds if the page is visible
    this.refreshInterval = setInterval(() => {
      if (!document.hidden) {
        this.refreshData()
      }
    }, 30000)
  }

  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }

  async refreshData() {
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.classList.add('loading')
    }

    try {
      const response = await fetch(window.location.href, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const html = await response.text()
        // Update the page content
        document.documentElement.innerHTML = html
      }
    } catch (error) {
      console.error('Failed to refresh analytics data:', error)
    } finally {
      if (this.hasRefreshButtonTarget) {
        this.refreshButtonTarget.classList.remove('loading')
      }
    }
  }

  async exportData(event) {
    event.preventDefault()
    
    if (this.hasExportButtonTarget) {
      this.exportButtonTarget.classList.add('loading')
    }

    try {
      const url = new URL(window.location.href)
      url.searchParams.set('format', 'json')
      
      const response = await fetch(url.toString(), {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.downloadJSON(data, `mcp-analytics-${new Date().toISOString().split('T')[0]}.json`)
      } else {
        throw new Error('Failed to export data')
      }
    } catch (error) {
      console.error('Failed to export analytics data:', error)
      this.showNotification('Failed to export data', 'error')
    } finally {
      if (this.hasExportButtonTarget) {
        this.exportButtonTarget.classList.remove('loading')
      }
    }
  }

  downloadJSON(data, filename) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    
    URL.revokeObjectURL(url)
    this.showNotification('Analytics data exported successfully', 'success')
  }

  showNotification(message, type = 'info') {
    // Create a toast notification
    const toast = document.createElement('div')
    toast.className = `alert alert-${type} fixed top-4 right-4 z-50 max-w-sm`
    toast.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      <span>${message}</span>
    `
    
    document.body.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
    }, 5000)
  }

  // Handle timeframe changes
  changeTimeframe(event) {
    const timeframe = event.target.dataset.timeframe
    if (timeframe) {
      const url = new URL(window.location.href)
      url.searchParams.set('timeframe', timeframe)
      window.location.href = url.toString()
    }
  }
}