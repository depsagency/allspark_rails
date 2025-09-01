import { Controller } from "@hotwired/stimulus"

// DataTable controller for enhanced table functionality
//
// Provides functionality for:
// - Live search with debouncing
// - Row selection
// - Bulk actions
// - Column sorting
// - Responsive table features
//
// Usage:
//   <div data-controller="data-table" data-data-table-search-delay-value="300">
//     <input data-data-table-target="searchInput" data-action="input->data-table#search">
//     <table data-data-table-target="table">
//       <!-- table content -->
//     </table>
//   </div>
//
export default class extends Controller {
  static values = {
    searchDelay: { type: Number, default: 300 },
    searchUrl: String,
    autoSubmit: { type: Boolean, default: false }
  }

  static targets = ["searchInput", "searchForm", "searchButton", "table", "selectAll", "selectedCount", "bulkActions"]

  connect() {
    this.searchTimeout = null
    this.selectedRows = new Set()
    this.updateSelectedCount()
  }

  disconnect() {
    this.clearSearchTimeout()
  }

  // Handle search input with debouncing
  search(event) {
    this.clearSearchTimeout()
    
    if (this.autoSubmitValue) {
      this.searchTimeout = setTimeout(() => {
        this.submitSearch()
      }, this.searchDelayValue)
    }
  }

  // Submit search form
  submitSearch() {
    if (this.hasSearchFormTarget) {
      this.searchFormTarget.requestSubmit()
    }
  }

  // Clear search timeout
  clearSearchTimeout() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
      this.searchTimeout = null
    }
  }

  // Handle individual row selection
  selectRow(event) {
    const checkbox = event.target
    const row = checkbox.closest('tr')
    const rowId = checkbox.value

    if (checkbox.checked) {
      this.selectedRows.add(rowId)
      row.classList.add('selected', 'bg-primary/10')
    } else {
      this.selectedRows.delete(rowId)
      row.classList.remove('selected', 'bg-primary/10')
    }

    this.updateSelectAllState()
    this.updateSelectedCount()
    this.updateBulkActions()
  }

  // Handle select all checkbox
  selectAll(event) {
    const checked = event.target.checked
    const checkboxes = this.element.querySelectorAll('tbody input[type="checkbox"]')
    
    checkboxes.forEach(checkbox => {
      checkbox.checked = checked
      const changeEvent = new Event('change', { bubbles: true })
      checkbox.dispatchEvent(changeEvent)
    })
  }

  // Update select all checkbox state
  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return

    const checkboxes = this.element.querySelectorAll('tbody input[type="checkbox"]')
    const checkedBoxes = this.element.querySelectorAll('tbody input[type="checkbox"]:checked')

    if (checkedBoxes.length === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checkedBoxes.length === checkboxes.length) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }
  }

  // Update selected count display
  updateSelectedCount() {
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = this.selectedRows.size
    }
  }

  // Show/hide bulk actions based on selection
  updateBulkActions() {
    if (this.hasBulkActionsTarget) {
      if (this.selectedRows.size > 0) {
        this.bulkActionsTarget.classList.remove('hidden')
      } else {
        this.bulkActionsTarget.classList.add('hidden')
      }
    }
  }

  // Get selected row IDs
  getSelectedIds() {
    return Array.from(this.selectedRows)
  }

  // Clear all selections
  clearSelection() {
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      checkbox.checked = false
    })
    
    this.selectedRows.clear()
    this.updateSelectedCount()
    this.updateBulkActions()
    this.updateSelectAllState()
    
    // Remove visual selection
    const rows = this.element.querySelectorAll('tr.selected')
    rows.forEach(row => {
      row.classList.remove('selected', 'bg-primary/10')
    })
  }

  // Handle bulk actions
  bulkAction(event) {
    const action = event.target.dataset.action
    const selectedIds = this.getSelectedIds()
    
    if (selectedIds.length === 0) {
      this.showAlert('Please select at least one item', 'warning')
      return
    }

    this.dispatch('bulkAction', {
      detail: {
        action: action,
        selectedIds: selectedIds,
        count: selectedIds.length
      }
    })
  }

  // Show alert message
  showAlert(message, type = 'info') {
    // Dispatch event for parent to handle
    this.dispatch('alert', {
      detail: {
        message: message,
        type: type
      }
    })
  }

  // Handle responsive table actions
  toggleRowDetails(event) {
    const button = event.target
    const row = button.closest('tr')
    const detailsRow = row.nextElementSibling
    
    if (detailsRow && detailsRow.classList.contains('details-row')) {
      const isHidden = detailsRow.style.display === 'none'
      detailsRow.style.display = isHidden ? '' : 'none'
      button.textContent = isHidden ? 'Hide Details' : 'Show Details'
    }
  }

  // Dispatch custom events
  dispatch(eventName, options = {}) {
    const event = new CustomEvent(`data-table:${eventName}`, {
      detail: { controller: this, ...options.detail },
      bubbles: true,
      cancelable: true
    })
    this.element.dispatchEvent(event)
  }
}