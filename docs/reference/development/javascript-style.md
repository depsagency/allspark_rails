# JavaScript Style Guide

This guide outlines the JavaScript coding conventions used in the AllSpark project, with a focus on Stimulus.js patterns.

## General JavaScript Style

### ES6+ Syntax
Always use modern JavaScript features:

```javascript
// Good - ES6+
const name = 'AllSpark';
const users = ['John', 'Jane'];
const greeting = `Hello, ${name}!`;

// Arrow functions for callbacks
users.map(user => user.toUpperCase());

// Destructuring
const { email, name } = user;
const [first, ...rest] = array;

// Bad - Old syntax
var name = 'AllSpark';
var greeting = 'Hello, ' + name + '!';
users.map(function(user) { return user.toUpperCase(); });
```

### Variable Declarations
- Use `const` by default
- Use `let` only when reassignment is needed
- Never use `var`

```javascript
// Good
const API_KEY = 'abc123';
const users = [];

let counter = 0;
counter += 1;

// Bad
var config = {};
let CONSTANT_VALUE = 42;
```

### Naming Conventions
- Use `camelCase` for variables and functions
- Use `PascalCase` for classes and constructors
- Use `UPPER_SNAKE_CASE` for constants

```javascript
// Good
const userName = 'John';
const calculateTotal = (items) => { /* ... */ };

class UserProfile {
  constructor() { /* ... */ }
}

const MAX_RETRY_COUNT = 3;
```

### Functions
- Prefer arrow functions for callbacks
- Use regular functions for methods
- Keep functions small and focused

```javascript
// Good
const processUsers = (users) => {
  return users
    .filter(user => user.active)
    .map(user => ({
      ...user,
      fullName: `${user.firstName} ${user.lastName}`
    }));
};

class UserService {
  constructor() {
    this.users = [];
  }

  // Regular function for methods
  addUser(user) {
    this.users.push(user);
  }
}
```

## Stimulus.js Conventions

### Controller Structure
Follow consistent structure for Stimulus controllers:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Define targets
  static targets = ["input", "output", "button"]
  
  // Define values
  static values = {
    url: String,
    interval: Number,
    active: Boolean
  }
  
  // Define classes
  static classes = ["hidden", "active"]

  // Lifecycle callbacks
  connect() {
    console.log("Controller connected:", this.element)
    this.initializeState()
  }

  disconnect() {
    this.cleanup()
  }

  // Value changed callbacks
  activeValueChanged() {
    this.updateDisplay()
  }

  // Actions
  submit(event) {
    event.preventDefault()
    this.processForm()
  }

  // Private methods
  initializeState() {
    // Setup code
  }

  cleanup() {
    // Cleanup code
  }
}
```

### Data Attributes
Use semantic naming for Stimulus attributes:

```html
<!-- Good -->
<div data-controller="user-form"
     data-user-form-url-value="/api/users"
     data-user-form-active-value="true">
  
  <input data-user-form-target="input"
         data-action="input->user-form#validate">
  
  <button data-action="click->user-form#submit">
    Submit
  </button>
</div>

<!-- Bad - unclear naming -->
<div data-controller="form"
     data-form-u-value="/api/users">
```

### Event Handling
Use Stimulus actions for all event handling:

```javascript
export default class extends Controller {
  static targets = ["modal", "trigger"]

  // Good - Clear action methods
  openModal(event) {
    event.preventDefault()
    this.modalTarget.classList.remove('hidden')
  }

  closeModal(event) {
    // Allow closing with Escape key or click
    if (event.type === 'keydown' && event.key !== 'Escape') return
    
    this.modalTarget.classList.add('hidden')
  }

  handleClickOutside(event) {
    if (event.target === this.modalTarget) {
      this.closeModal(event)
    }
  }
}
```

### State Management
Keep state in data attributes when possible:

```javascript
export default class extends Controller {
  static values = { 
    count: Number,
    items: Array 
  }

  increment() {
    this.countValue++  // Automatically triggers countValueChanged
  }

  addItem(event) {
    const newItem = event.target.value
    this.itemsValue = [...this.itemsValue, newItem]
  }

  countValueChanged() {
    this.updateDisplay()
  }

  updateDisplay() {
    this.element.querySelector('[data-count]').textContent = this.countValue
  }
}
```

## Async Operations

### Promises and Async/Await
Always use async/await for asynchronous operations:

```javascript
// Good
export default class extends Controller {
  async loadData() {
    try {
      this.showLoading()
      const response = await fetch(this.urlValue)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      this.displayData(data)
    } catch (error) {
      this.showError(error.message)
    } finally {
      this.hideLoading()
    }
  }

  showLoading() {
    this.element.classList.add('loading')
  }

  hideLoading() {
    this.element.classList.remove('loading')
  }
}
```

### Error Handling
Always handle errors appropriately:

```javascript
export default class extends Controller {
  async submitForm(event) {
    event.preventDefault()
    
    try {
      const formData = new FormData(event.target)
      const response = await this.postData(formData)
      
      if (response.redirectUrl) {
        window.location.href = response.redirectUrl
      } else {
        this.showSuccess('Form submitted successfully!')
      }
    } catch (error) {
      console.error('Form submission error:', error)
      
      if (error.response?.status === 422) {
        this.showValidationErrors(error.response.data.errors)
      } else {
        this.showError('An unexpected error occurred. Please try again.')
      }
    }
  }

  async postData(formData) {
    const response = await fetch(this.urlValue, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
      },
      body: formData
    })

    if (!response.ok) {
      const error = new Error('Network response was not ok')
      error.response = response
      throw error
    }

    return response.json()
  }
}
```

## Module Organization

### File Structure
```
app/javascript/
├── controllers/
│   ├── index.js          # Stimulus controller registration
│   ├── hello_controller.js
│   └── form_validation_controller.js
├── utils/
│   ├── debounce.js
│   └── api_client.js
├── config/
│   └── constants.js
└── application.js        # Entry point
```

### Exports and Imports
Use ES6 modules consistently:

```javascript
// utils/debounce.js
export function debounce(func, wait) {
  let timeout
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
}

// controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"
import { debounce } from "../utils/debounce"

export default class extends Controller {
  initialize() {
    this.search = debounce(this.search.bind(this), 300)
  }

  search() {
    // Debounced search logic
  }
}
```

## Testing JavaScript

### Stimulus Controller Tests
```javascript
import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-webpack-helpers"

describe("ToggleController", () => {
  let application
  
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="toggle"
           data-toggle-hidden-class="hidden">
        <button data-action="toggle#toggle">Toggle</button>
        <div data-toggle-target="content" class="hidden">
          Content
        </div>
      </div>
    `
    
    application = Application.start()
    const context = require.context("./controllers", true, /\.js$/)
    application.load(definitionsFromContext(context))
  })

  afterEach(() => {
    application.stop()
  })

  it("toggles content visibility", () => {
    const button = document.querySelector('[data-action="toggle#toggle"]')
    const content = document.querySelector('[data-toggle-target="content"]')
    
    expect(content.classList.contains('hidden')).toBe(true)
    
    button.click()
    expect(content.classList.contains('hidden')).toBe(false)
    
    button.click()
    expect(content.classList.contains('hidden')).toBe(true)
  })
})
```

## Performance Best Practices

### Debouncing and Throttling
```javascript
import { Controller } from "@hotwired/stimulus"
import { debounce, throttle } from "../utils/timing"

export default class extends Controller {
  connect() {
    // Debounce search input
    this.search = debounce(this.performSearch.bind(this), 300)
    
    // Throttle scroll events
    this.handleScroll = throttle(this.updateScrollPosition.bind(this), 100)
    
    window.addEventListener('scroll', this.handleScroll)
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }
}
```

### DOM Manipulation
Minimize DOM operations:

```javascript
// Good - Batch DOM updates
export default class extends Controller {
  updateList(items) {
    const fragment = document.createDocumentFragment()
    
    items.forEach(item => {
      const li = document.createElement('li')
      li.textContent = item.name
      li.dataset.itemId = item.id
      fragment.appendChild(li)
    })
    
    this.listTarget.innerHTML = ''
    this.listTarget.appendChild(fragment)
  }
}

// Bad - Multiple DOM operations
export default class extends Controller {
  updateList(items) {
    this.listTarget.innerHTML = ''
    items.forEach(item => {
      const li = document.createElement('li')
      li.textContent = item.name
      this.listTarget.appendChild(li)  // DOM operation in loop
    })
  }
}
```

## Code Quality Tools

### ESLint Configuration
```json
{
  "extends": ["eslint:recommended"],
  "parserOptions": {
    "ecmaVersion": 2022,
    "sourceType": "module"
  },
  "env": {
    "browser": true,
    "es2022": true
  },
  "rules": {
    "indent": ["error", 2],
    "quotes": ["error", "single"],
    "semi": ["error", "never"],
    "no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
```

### Prettier Configuration
```json
{
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "semi": false,
  "singleQuote": true,
  "trailingComma": "es5",
  "bracketSpacing": true,
  "arrowParens": "avoid"
}
```