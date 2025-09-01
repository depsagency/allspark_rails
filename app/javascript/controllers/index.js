// Entry point for the build script in your package.json
import { Application } from '@hotwired/stimulus'
import controllers from './*_controller.js'


const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus = application

controllers.forEach((controller) => {
  application.register(controller.name, controller.module.default)
})

// Debug: Log all registered controllers
console.log('Registered Stimulus controllers:', controllers.map(c => c.name))

// Check for workflow-execution controller
const hasWorkflowExecution = controllers.some(c => c.name === 'workflow-execution')
console.log('workflow-execution controller found:', hasWorkflowExecution)
