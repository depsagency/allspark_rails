import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "pane"]

  connect() {
    console.log("Tabs controller connected")
    // Ensure first tab is active on load
    this.showTab(0)
  }

  switchTab(event) {
    event.preventDefault()
    const clickedTab = event.currentTarget
    const targetPane = clickedTab.dataset.tab

    console.log("Switching to tab:", targetPane)

    // Update active tab
    this.tabTargets.forEach(tab => {
      tab.classList.remove('tab-active')
    })
    clickedTab.classList.add('tab-active')

    // Show corresponding pane
    this.paneTargets.forEach(pane => {
      if (pane.dataset.content === targetPane) {
        pane.classList.remove('hidden')
        pane.classList.add('active')
        console.log("Showing pane:", targetPane)
      } else {
        pane.classList.add('hidden')
        pane.classList.remove('active')
      }
    })
  }

  showTab(index) {
    if (this.tabTargets[index] && this.paneTargets[index]) {
      // Activate the tab
      this.tabTargets.forEach((tab, i) => {
        if (i === index) {
          tab.classList.add('tab-active')
        } else {
          tab.classList.remove('tab-active')
        }
      })

      // Show the corresponding pane
      this.paneTargets.forEach((pane, i) => {
        if (i === index) {
          pane.classList.remove('hidden')
          pane.classList.add('active')
        } else {
          pane.classList.add('hidden')
          pane.classList.remove('active')
        }
      })
    }
  }
}