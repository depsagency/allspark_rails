import { createConsumer } from '@rails/actioncable';
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';

// Make Terminal available globally for test pages
window.Terminal = Terminal;

// xterm.js terminal functionality
let terminal;
let terminalVisible = true;
let currentProjectId = null;

// Initialize terminal when page loads
function setupTerminal() {
  const terminalElement = document.getElementById('terminal');
  
  // Only initialize if we're NOT on a test page
  if (terminalElement && !terminal && !window.location.pathname.includes('/terminal/')) {
    console.log('Initializing xterm.js terminal...');
    initializeTerminal();
  }
}

// Handle both initial load and Turbo navigation
document.addEventListener('DOMContentLoaded', setupTerminal);
document.addEventListener('turbo:load', setupTerminal);

function initializeTerminal() {
  try {
    console.log('xterm.js available:', !!Terminal);
    
    // Create xterm.js terminal with fixed dimensions for reliable scrolling
    terminal = new Terminal({
      cols: 100,
      rows: 24,
      fontSize: 12,
      fontFamily: 'Monaco, Menlo, "Ubuntu Mono", monospace',
      theme: {
        background: '#000000',
        foreground: '#ffffff',
        cursor: '#ffffff'
      },
      cursorBlink: true,
      scrollback: 1000,
      scrollOnUserInput: true,
      smoothScrollDuration: 0,
      convertEol: true
    });
    
    // Open terminal in the DOM element
    terminal.open(document.getElementById('terminal'));
    
    // Write welcome message
    terminal.write('Terminal ready. Type commands below.\r\n$ ');
    
    updateTerminalStatus('Initializing...');
    
    // Connect to WebSocket
    connectTerminalWebSocket();
    
    // Handle user input - pass ALL data directly to backend
    terminal.onData(data => {
      if (window.terminalSubscription) {
        const payload = {
          type: 'input',
          data: data
        };
        
        window.terminalSubscription.perform('receive', payload);
      }
    });
    
  } catch (error) {
    console.error('Error initializing terminal:', error);
    updateTerminalStatus('Error');
  }
}

function connectTerminalWebSocket() {
  console.log('🔍 Attempting to connect to TerminalChannel...');
  const consumer = createConsumer();
  
  const subscription = consumer.subscriptions.create('TerminalChannel', {
    connected() {
      console.log('✅ Connected to TerminalChannel');
      updateTerminalStatus('Connected');
      
      // Send initial terminal size
      this.perform('receive', {
        type: 'resize',
        cols: 100,
        rows: 24
      });
    },
    
    disconnected() {
      console.log('❌ Disconnected from TerminalChannel');
      updateTerminalStatus('Disconnected');
    },
    
    rejected() {
      console.log('❌ TerminalChannel connection rejected');
      updateTerminalStatus('Rejected');
    },
    
    received(data) {
      console.log('📨 Received terminal data:', data);
      if (data.type === 'output' && terminal) {
        // Display output in xterm.js terminal
        terminal.write(data.data);
      } else if (data.type === 'status') {
        updateTerminalStatus(data.status);
      }
    }
  });
  
  console.log('🔍 Terminal subscription created:', !!subscription);
  window.terminalSubscription = subscription;
  
  // No resize handling needed with fixed dimensions
}

function updateTerminalStatus(status) {
  const statusElement = document.getElementById('terminal-status');
  if (statusElement) {
    statusElement.textContent = status;
    statusElement.className = `badge ${
      status === 'Connected' ? 'badge-success' : 
      status === 'Disconnected' ? 'badge-error' : 
      'badge-ghost'
    }`;
  }
}


// Terminal controls
document.addEventListener('click', function(e) {
  console.log('🔍 Click event fired, target:', e.target.id, e.target.className);
  
  // Check if the clicked element or its parent is the terminal-toggle button
  const toggleButton = e.target.closest('#terminal-toggle');
  if (toggleButton) {
    terminalVisible = !terminalVisible;
    const container = document.getElementById('terminal-container');
    const toggleText = document.getElementById('terminal-toggle-text');
    
    if (container && toggleText) {
      container.style.display = terminalVisible ? 'block' : 'none';
      toggleText.textContent = terminalVisible ? 'Hide' : 'Show';
    }
  }
  
  if (e.target.id === 'terminal-clear') {
    console.log('🔍 Terminal clear button clicked');
    if (terminal) {
      terminal.clear();
    }
  }
  
  // Handle Start Development button
  if (e.target.id === 'start-development-btn') {
    console.log('🚀 Start Development button clicked');
    const projectId = e.target.getAttribute('data-project-id');
    
    if (window.terminalSubscription && projectId) {
      // Show loading state
      e.target.classList.add('loading');
      e.target.disabled = true;
      
      // Send start development command to terminal channel
      window.terminalSubscription.perform('receive', {
        type: 'start_development_command',
        project_id: projectId
      });
      
      // Reset button state after a short delay
      setTimeout(() => {
        e.target.classList.remove('loading');
        e.target.disabled = false;
      }, 3000);
    } else {
      console.error('❌ Terminal not connected or missing project ID');
    }
  }
});

// startDevelopment function removed - now using simple clipboard copy