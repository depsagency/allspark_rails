// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the `bin/rails generate channel` command.

import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()

// Make consumer available globally for debugging
window.App = window.App || {}
window.App.cable = consumer

console.log("ActionCable consumer created")

export default consumer