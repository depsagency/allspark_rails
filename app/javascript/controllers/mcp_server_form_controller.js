import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 
    "authTypeSelect", 
    "apiKeyFields", 
    "bearerTokenFields", 
    "oauthFields",
    "nameInput",
    "endpointInput",
    "linearHelp"
  ]

  connect() {
    this.toggleAuthFields()
    this.checkForLinear()
  }

  toggleAuthFields() {
    const authType = this.authTypeSelectTarget.value
    
    // Hide all auth field sections
    if (this.hasApiKeyFieldsTarget) {
      this.apiKeyFieldsTarget.style.display = 'none'
    }
    if (this.hasBearerTokenFieldsTarget) {
      this.bearerTokenFieldsTarget.style.display = 'none'
    }
    if (this.hasOauthFieldsTarget) {
      this.oauthFieldsTarget.style.display = 'none'
    }
    
    // Show the appropriate section
    switch(authType) {
      case 'api_key':
        if (this.hasApiKeyFieldsTarget) {
          this.apiKeyFieldsTarget.style.display = 'block'
        }
        break
      case 'bearer_token':
        if (this.hasBearerTokenFieldsTarget) {
          this.bearerTokenFieldsTarget.style.display = 'block'
        }
        break
      case 'oauth':
        if (this.hasOauthFieldsTarget) {
          this.oauthFieldsTarget.style.display = 'block'
        }
        break
    }
    
    this.checkForLinear()
  }

  togglePasswordVisibility(event) {
    const button = event.currentTarget
    const inputName = button.dataset.targetInput
    const input = this.element.querySelector(`[data-target="mcp-server-form.${inputName}Input"]`)
    
    if (input) {
      if (input.type === 'password') {
        input.type = 'text'
        button.innerHTML = `
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"></path>
          </svg>
        `
      } else {
        input.type = 'password'
        button.innerHTML = `
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
          </svg>
        `
      }
    }
  }

  updateTransportOptions() {
    // This can be used to update auth options based on transport type
    // For example, SSE might have different auth requirements
    const transportType = event.currentTarget.value
    
    if (transportType === 'sse') {
      // SSE-specific options
      console.log('SSE transport selected')
    }
  }

  checkForLinear() {
    // Check if this is a Linear server
    const name = this.hasNameInputTarget ? this.nameInputTarget.value : ''
    const endpoint = this.hasEndpointInputTarget ? this.endpointInputTarget.value : ''
    const authType = this.authTypeSelectTarget.value
    
    const isLinear = name.toLowerCase().includes('linear') || 
                     endpoint.includes('linear.app')
    
    // Show/hide Linear help
    if (this.hasLinearHelpTarget) {
      if (isLinear && authType === 'api_key') {
        this.linearHelpTarget.style.display = 'block'
      } else {
        this.linearHelpTarget.style.display = 'none'
      }
    }
  }

  // Call this when name or endpoint changes
  inputChanged() {
    this.checkForLinear()
  }
}