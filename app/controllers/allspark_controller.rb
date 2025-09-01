# frozen_string_literal: true

class AllsparkController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, if: :devise_controller_exists?
  before_action :verify_allspark_enabled, except: [:monitor_js, :ping]
  
  # Serve the AllSpark monitoring JavaScript
  def monitor_js
    js_content = <<~JAVASCRIPT
      // AllSpark Client-Side Monitoring
      (function() {
        'use strict';
        
        if (typeof window.AllSparkConfig === 'undefined') {
          console.warn('[AllSpark] Configuration not found');
          return;
        }
        
        const config = window.AllSparkConfig;
        console.log('[AllSpark] Initializing with config:', config);
        
        // DevTools communication setup
        function setupDevToolsCommunication() {
          console.log('[AllSpark] Setting up DevTools communication');
          
          window.addEventListener('message', function(event) {
            console.log('[AllSpark] Received message:', event);
            
            // Accept messages from builder domains
            if (!event.origin.includes('builder.localhost') && !event.origin.includes('localhost')) {
              console.log('[AllSpark] Message rejected - invalid origin:', event.origin);
              return;
            }
            
            const message = event.data;
            
            if (message && message.type) {
              console.log('[AllSpark] Processing message type:', message.type);
              
              switch (message.type) {
                case 'devtools-ping':
                  console.log('[AllSpark] Responding to DevTools ping');
                  // Respond to DevTools ping
                  event.source.postMessage({
                    type: 'devtools-pong',
                    allsparkEnabled: true,
                    config: {
                      appProjectId: config.appProjectId,
                      buildSessionId: config.buildSessionId,
                      monitoringLevel: config.monitoringLevel
                    }
                  }, event.origin);
                  break;
                  
                case 'capture-dom':
                  console.log('[AllSpark] Capturing DOM');
                  // Capture DOM structure
                  const domData = {
                    type: 'dom-data',
                    html: document.documentElement.outerHTML,
                    url: window.location.href,
                    title: document.title,
                    timestamp: new Date().toISOString()
                  };
                  event.source.postMessage(domData, event.origin);
                  break;
                  
                case 'get-performance':
                  console.log('[AllSpark] Getting performance data');
                  // Get performance metrics - serialize timing object to avoid clone errors
                  let timingData = null;
                  if (window.performance && window.performance.timing) {
                    const t = window.performance.timing;
                    timingData = {
                      navigationStart: t.navigationStart,
                      domainLookupStart: t.domainLookupStart,
                      domainLookupEnd: t.domainLookupEnd,
                      connectStart: t.connectStart,
                      connectEnd: t.connectEnd,
                      requestStart: t.requestStart,
                      responseStart: t.responseStart,
                      responseEnd: t.responseEnd,
                      domLoading: t.domLoading,
                      domInteractive: t.domInteractive,
                      domContentLoadedEventStart: t.domContentLoadedEventStart,
                      domContentLoadedEventEnd: t.domContentLoadedEventEnd,
                      domComplete: t.domComplete,
                      loadEventStart: t.loadEventStart,
                      loadEventEnd: t.loadEventEnd
                    };
                  }
                  
                  const perfData = {
                    type: 'performance-data',
                    timing: timingData,
                    navigation: window.performance && window.performance.navigation ? {
                      type: window.performance.navigation.type,
                      redirectCount: window.performance.navigation.redirectCount
                    } : null,
                    timestamp: new Date().toISOString()
                  };
                  event.source.postMessage(perfData, event.origin);
                  break;
              }
            }
          });
          
          // Send ready signal to parent frame
          if (window.parent !== window) {
            console.log('[AllSpark] Sending ready signal to parent frame');
            window.parent.postMessage({
              type: 'allspark-ready',
              config: {
                appProjectId: config.appProjectId,
                buildSessionId: config.buildSessionId,
                monitoringLevel: config.monitoringLevel
              }
            }, '*');
          }
        }
        
        // Error monitoring
        function setupErrorMonitoring() {
          if (!config.enableError) return;
          
          console.log('[AllSpark] Setting up error monitoring');
          
          window.addEventListener('error', function(event) {
            console.log('[AllSpark] JavaScript error captured:', event);
            const errorData = {
              message: event.message,
              filename: event.filename,
              lineno: event.lineno,
              colno: event.colno,
              stack: event.error ? event.error.stack : null,
              timestamp: new Date().toISOString(),
              url: window.location.href
            };
            
            sendToBuilder('javascript_error', errorData);
          });
          
          window.addEventListener('unhandledrejection', function(event) {
            console.log('[AllSpark] Promise rejection captured:', event);
            const errorData = {
              message: 'Unhandled Promise Rejection: ' + event.reason,
              stack: event.reason && event.reason.stack ? event.reason.stack : null,
              timestamp: new Date().toISOString(),
              url: window.location.href
            };
            
            sendToBuilder('javascript_error', errorData);
          });
        }
        
        // Send data to builder
        function sendToBuilder(eventType, data) {
          console.log('[AllSpark] Sending to builder:', eventType, data);
          
          // Send to parent frame if in iframe (for DevTools)
          if (window.parent !== window) {
            window.parent.postMessage({
              type: 'allspark-monitoring',
              payload: {
                event_type: eventType,
                data: data,
                context: {
                  app_project_id: config.appProjectId,
                  build_session_id: config.buildSessionId,
                  session_id: config.sessionId,
                  request_id: config.requestId
                },
                timestamp: new Date().toISOString(),
                app_id: config.appId
              }
            }, '*');
          }
          
          // Also try direct webhook if available
          if (config.webhookUrl && window.fetch) {
            const payload = {
              event_type: eventType,
              data: data,
              context: {
                app_project_id: config.appProjectId,
                build_session_id: config.buildSessionId,
                session_id: config.sessionId,
                request_id: config.requestId
              },
              timestamp: new Date().toISOString(),
              app_id: config.appId
            };
            
            fetch(config.webhookUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + config.apiKey
              },
              body: JSON.stringify(payload)
            }).catch(function(error) {
              console.warn('[AllSpark] Failed to send monitoring data:', error.message);
            });
          }
        }
        
        // Initialize monitoring
        function initialize() {
          console.log('[AllSpark] Client monitoring initialized');
          setupDevToolsCommunication();
          setupErrorMonitoring();
        }
        
        // Start when DOM is ready
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', initialize);
        } else {
          initialize();
        }
        
      })();
    JAVASCRIPT

    render plain: js_content, content_type: 'application/javascript'
  end
  
  # DevTools ping endpoint
  def ping
    render json: {
      status: 'ok',
      allspark_enabled: AllSpark.configuration&.enabled? || false,
      config: {
        app_project_id: AllSpark.configuration&.app_project_id,
        build_session_id: AllSpark.configuration&.build_session_id,
        monitoring_level: AllSpark.configuration&.monitoring_level,
        features: {
          console_monitoring: AllSpark.configuration&.console_monitoring,
          network_monitoring: AllSpark.configuration&.network_monitoring,
          performance_monitoring: AllSpark.configuration&.performance_monitoring,
          error_monitoring: AllSpark.configuration&.error_monitoring,
          dom_monitoring: AllSpark.configuration&.dom_monitoring
        }
      }
    }
  end
  
  # Handle DevTools commands
  def devtools
    case params[:command]
    when 'ping'
      render json: { status: 'pong', timestamp: Time.now.iso8601 }
    when 'status'
      render json: {
        status: 'online',
        config: AllSpark.configuration&.to_client_config || {},
        timestamp: Time.now.iso8601
      }
    else
      render json: { error: 'Unknown command' }, status: 400
    end
  end
  
  private
  
  def verify_allspark_enabled
    unless AllSpark.configuration&.enabled?
      render json: { error: 'AllSpark not enabled' }, status: 403
    end
  end
  
  def devise_controller_exists?
    defined?(Devise) && respond_to?(:authenticate_user!)
  end
end