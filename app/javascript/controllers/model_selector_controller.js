import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modelSelect", "modelDescription", "customModelInput"]
  
  connect() {
    console.log('🚨 NEW VERSION: Model selector controller connected!')
    console.log('Element:', this.element)
    
    try {
      // Check if targets exist
      if (this.hasModelSelectTarget) {
        console.log('Model select target found:', this.modelSelectTarget)
        // Store the current model value
        this.currentModelValue = this.modelSelectTarget.value || this.modelSelectTarget.dataset.currentValue
        console.log('Current model value:', this.currentModelValue)
      } else {
        console.error('Model select target NOT found!')
        return
      }
      
      // The controller is attached to the provider select element
      console.log('Provider select is the controller element:', this.element)
      
      // Initialize models on page load
      this.updateModels()
    } catch (error) {
      console.error('Error in connect:', error)
    }
  }
  
  updateModels() {
    let models = []
    
    try {
      console.log('Updating models...')
      
      // Find the provider select element - it's now a child of the controller element
      const providerSelect = this.element.querySelector('#model_provider')
      console.log('Provider select:', providerSelect)
      console.log('Selected index:', providerSelect.selectedIndex)
      
      if (providerSelect.selectedIndex < 0) {
        console.log('No option selected yet')
        return
      }
      
      const selectedOption = providerSelect.options[providerSelect.selectedIndex]
      console.log('Selected provider option:', selectedOption)
      
      if (!selectedOption) {
        console.error('Selected option is undefined!')
        return
      }
      
      const modelsData = selectedOption.dataset.models
      console.log('Models data:', modelsData)
      
      models = JSON.parse(modelsData || '[]')
      console.log('Available models:', models)
    } catch (error) {
      console.error('Error in updateModels:', error)
      return
    }
    
    // Clear existing options
    this.modelSelectTarget.innerHTML = ''
    
    // Add prompt option
    const promptOption = document.createElement('option')
    promptOption.value = ''
    promptOption.textContent = 'Select a model...'
    this.modelSelectTarget.appendChild(promptOption)
    
    // Add model options
    let modelFound = false
    models.forEach(model => {
      const option = document.createElement('option')
      option.value = model.value
      option.textContent = model.name
      option.dataset.description = model.description
      
      // Select this option if it matches the current model
      if (this.currentModelValue && model.value === this.currentModelValue) {
        option.selected = true
        modelFound = true
        this.modelDescriptionTarget.textContent = model.description
      }
      
      this.modelSelectTarget.appendChild(option)
    })
    
    // Add custom model option
    const customOption = document.createElement('option')
    customOption.value = 'custom'
    customOption.textContent = 'Custom Model...'
    this.modelSelectTarget.appendChild(customOption)
    
    // If current model wasn't found in the list, it might be custom
    if (this.currentModelValue && !modelFound && this.currentModelValue !== '') {
      customOption.selected = true
      this.customModelInputTarget.classList.remove('hidden')
      this.customModelInputTarget.querySelector('input').value = this.currentModelValue
      this.modelDescriptionTarget.textContent = 'Custom model: ' + this.currentModelValue
    }
    
    // Update model select event listener
    this.modelSelectTarget.removeEventListener('change', this.boundModelChange)
    this.boundModelChange = this.modelChanged.bind(this)
    this.modelSelectTarget.addEventListener('change', this.boundModelChange)
    
    // Only reset if no model is selected
    if (!this.currentModelValue) {
      this.modelDescriptionTarget.textContent = 'Select a model to see details'
      this.customModelInputTarget.classList.add('hidden')
    }
  }
  
  modelChanged(event) {
    const selectedValue = event.target.value
    const selectedOption = event.target.options[event.target.selectedIndex]
    
    if (selectedValue === 'custom') {
      // Show custom model input
      this.customModelInputTarget.classList.remove('hidden')
      this.modelDescriptionTarget.textContent = 'Enter a custom model identifier'
      
      // Set the actual model name field to empty so custom input is used
      this.modelSelectTarget.name = ''
      this.customModelInputTarget.querySelector('input').name = 'assistant[llm_model_name]'
    } else if (selectedValue === '') {
      // No model selected
      this.customModelInputTarget.classList.add('hidden')
      this.modelDescriptionTarget.textContent = 'Select a model to see details'
      this.modelSelectTarget.name = 'assistant[llm_model_name]'
    } else {
      // Regular model selected
      this.customModelInputTarget.classList.add('hidden')
      this.modelDescriptionTarget.textContent = selectedOption.dataset.description || ''
      this.modelSelectTarget.name = 'assistant[llm_model_name]'
    }
  }
  
  disconnect() {
    // Clean up event listener
    if (this.boundModelChange) {
      this.modelSelectTarget.removeEventListener('change', this.boundModelChange)
    }
  }
}