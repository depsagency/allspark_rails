// DevTools Monitor - Enables monitoring capabilities for AllSpark Builder DevTools
// This file handles all postMessage communication between the target application and DevTools

(function() {
  'use strict';

  // Only initialize in development or when DevTools is explicitly enabled
  const devtoolsEnabled = document.querySelector('meta[name="devtools-enabled"]');
  if (!devtoolsEnabled || devtoolsEnabled.content !== 'true') {
    return;
  }

  console.log('DevTools: Initializing monitoring system');

  // DevTools comprehensive postMessage handler
  window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (!data || !data.type) return;
    
    try {
      switch (data.type) {
        case 'devtools-ping':
          handleDevToolsPing(event);
          break;
          
        case 'capture-dom':
          handleCaptureDom(event, data);
          break;
          
        case 'capture-console':
          handleCaptureConsole(event, data);
          break;
          
        case 'capture-network':
          handleCaptureNetwork(event, data);
          break;
          
        case 'capture-errors':
          handleCaptureErrors(event, data);
          break;
          
        case 'get-performance':
        case 'collect-performance':
          handleGetPerformance(event, data);
          break;
          
        default:
          console.log('DevTools: Unknown message type:', data.type);
      }
    } catch (error) {
      console.error('DevTools: Error handling message:', error);
      event.source.postMessage({
        type: 'devtools-error',
        message: error.message,
        timestamp: Date.now()
      }, event.origin);
    }
  });

  // Handle DevTools ping for connection verification
  function handleDevToolsPing(event) {
    console.log('DevTools: Received ping, sending pong response');
    event.source.postMessage({
      type: 'devtools-pong',
      timestamp: Date.now(),
      devtoolsEnabled: true
    }, event.origin);
  }

  // Handle DOM capture requests
  function handleCaptureDom(event, data) {
    console.log('DevTools: Capturing DOM structure');
    const domData = {
      type: 'dom-data',
      requestId: data.requestId,
      timestamp: Date.now(),
      html: document.documentElement.outerHTML,
      url: window.location.href,
      title: document.title,
      bodyClasses: document.body.className,
      elements: {
        total: document.querySelectorAll('*').length,
        forms: document.querySelectorAll('form').length,
        inputs: document.querySelectorAll('input').length,
        links: document.querySelectorAll('a').length,
        images: document.querySelectorAll('img').length
      }
    };
    event.source.postMessage(domData, event.origin);
  }

  // Handle console capture setup
  function handleCaptureConsole(event, data) {
    console.log('DevTools: Setting up console capture');
    
    // Store original console methods if not already stored
    if (!window._originalConsole) {
      window._originalConsole = {
        log: console.log,
        warn: console.warn,
        error: console.error,
        info: console.info
      };
    }
    
    // Override console methods to capture logs
    ['log', 'warn', 'error', 'info'].forEach(method => {
      console[method] = function(...args) {
        // Call original method
        window._originalConsole[method].apply(console, args);
        
        // Send to DevTools
        event.source.postMessage({
          type: 'console-log',
          level: method,
          timestamp: Date.now(),
          args: args.map(arg => {
            try {
              return typeof arg === 'object' ? JSON.stringify(arg, null, 2) : String(arg);
            } catch (e) {
              return String(arg);
            }
          })
        }, event.origin);
      };
    });
    
    event.source.postMessage({
      type: 'console-capture-enabled',
      requestId: data.requestId,
      timestamp: Date.now()
    }, event.origin);
  }

  // Handle network monitoring setup
  function handleCaptureNetwork(event, data) {
    console.log('DevTools: Setting up network monitoring');
    
    // Override fetch
    if (!window._originalFetch) {
      window._originalFetch = window.fetch;
      window.fetch = function(...args) {
        const startTime = Date.now();
        const url = args[0];
        const options = args[1] || {};
        
        return window._originalFetch.apply(this, args)
          .then(response => {
            event.source.postMessage({
              type: 'network-request',
              timestamp: startTime,
              duration: Date.now() - startTime,
              url: url,
              method: options.method || 'GET',
              status: response.status,
              statusText: response.statusText,
              headers: Object.fromEntries(response.headers.entries())
            }, event.origin);
            return response;
          })
          .catch(error => {
            event.source.postMessage({
              type: 'network-error',
              timestamp: startTime,
              duration: Date.now() - startTime,
              url: url,
              method: options.method || 'GET',
              error: error.message
            }, event.origin);
            throw error;
          });
      };
    }
    
    // Override XMLHttpRequest
    if (!window._originalXHR) {
      window._originalXHR = window.XMLHttpRequest;
      window.XMLHttpRequest = function() {
        const xhr = new window._originalXHR();
        const originalOpen = xhr.open;
        const originalSend = xhr.send;
        let startTime, method, url;
        
        xhr.open = function(m, u, ...args) {
          method = m;
          url = u;
          return originalOpen.apply(this, [m, u, ...args]);
        };
        
        xhr.send = function(...args) {
          startTime = Date.now();
          
          xhr.addEventListener('loadend', function() {
            event.source.postMessage({
              type: 'network-request',
              timestamp: startTime,
              duration: Date.now() - startTime,
              url: url,
              method: method,
              status: xhr.status,
              statusText: xhr.statusText
            }, event.origin);
          });
          
          return originalSend.apply(this, args);
        };
        
        return xhr;
      };
    }
    
    event.source.postMessage({
      type: 'network-capture-enabled',
      requestId: data.requestId,
      timestamp: Date.now()
    }, event.origin);
  }

  // Handle error capture setup
  function handleCaptureErrors(event, data) {
    console.log('DevTools: Setting up error capture');
    
    // Global error handler
    if (!window._devToolsErrorHandler) {
      window._devToolsErrorHandler = function(errorEvent) {
        event.source.postMessage({
          type: 'javascript-error',
          timestamp: Date.now(),
          message: errorEvent.error ? errorEvent.error.message : errorEvent.message,
          filename: errorEvent.filename,
          lineno: errorEvent.lineno,
          colno: errorEvent.colno,
          stack: errorEvent.error ? errorEvent.error.stack : null
        }, event.origin);
      };
      
      window.addEventListener('error', window._devToolsErrorHandler);
      
      // Unhandled promise rejections
      window.addEventListener('unhandledrejection', function(rejectionEvent) {
        event.source.postMessage({
          type: 'javascript-error',
          timestamp: Date.now(),
          message: 'Unhandled Promise Rejection: ' + (rejectionEvent.reason.message || rejectionEvent.reason),
          stack: rejectionEvent.reason.stack || null
        }, event.origin);
      });
    }
    
    event.source.postMessage({
      type: 'error-capture-enabled',
      requestId: data.requestId,
      timestamp: Date.now()
    }, event.origin);
  }

  // Handle performance metrics capture
  function handleGetPerformance(event, data) {
    console.log('DevTools: Capturing performance metrics');
    
    try {
      // Convert performance entries to plain objects to avoid serialization issues
      const navEntry = performance.getEntriesByType('navigation')[0];
      const navigation = navEntry ? {
        domComplete: navEntry.domComplete,
        domContentLoadedEventEnd: navEntry.domContentLoadedEventEnd,
        domContentLoadedEventStart: navEntry.domContentLoadedEventStart,
        domInteractive: navEntry.domInteractive,
        loadEventEnd: navEntry.loadEventEnd,
        loadEventStart: navEntry.loadEventStart,
        responseEnd: navEntry.responseEnd,
        responseStart: navEntry.responseStart,
        type: navEntry.type,
        redirectCount: navEntry.redirectCount
      } : {};
      
      const resources = performance.getEntriesByType('resource').slice(-20).map(r => ({
        name: r.name,
        startTime: r.startTime,
        duration: r.duration,
        initiatorType: r.initiatorType,
        transferSize: r.transferSize || 0,
        encodedBodySize: r.encodedBodySize || 0
      }));
      
      const perfData = {
        type: 'performance-data',
        requestId: data.requestId,
        timestamp: Date.now(),
        navigation: navigation,
        resources: resources,
        memory: performance.memory ? {
          usedJSHeapSize: performance.memory.usedJSHeapSize,
          totalJSHeapSize: performance.memory.totalJSHeapSize,
          jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
        } : null,
        timing: performance.timing ? {
          loadComplete: performance.timing.loadEventEnd - performance.timing.navigationStart,
          domReady: performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart,
          firstPaint: performance.getEntriesByType('paint').find(p => p.name === 'first-paint')?.startTime || null
        } : null
      };
      
      event.source.postMessage(perfData, event.origin);
    } catch (error) {
      console.error('DevTools: Error capturing performance data:', error);
      event.source.postMessage({
        type: 'performance-error',
        message: error.message,
        timestamp: Date.now()
      }, event.origin);
    }
  }

  console.log('DevTools: Comprehensive postMessage handler initialized');
})();