require 'rails_helper'

RSpec.describe McpConfigValidator, type: :service do
  describe '#validate' do
    context 'with valid HTTP configuration' do
      let(:config) do
        {
          "name" => "Test Server",
          "server_type" => "http",
          "server_config" => {
            "endpoint" => "https://api.example.com/mcp"
          }
        }
      end
      
      it 'returns success' do
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end
    
    context 'with invalid configuration' do
      it 'validates missing name' do
        config = {
          "server_type" => "http",
          "server_config" => { "endpoint" => "https://test.com" }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Name is required")
      end
      
      it 'validates missing server_type' do
        config = {
          "name" => "Test",
          "server_config" => { "endpoint" => "https://test.com" }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Server type is required")
      end
      
      it 'validates invalid server_type' do
        config = {
          "name" => "Test",
          "server_type" => "invalid",
          "server_config" => {}
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Invalid server type: invalid")
      end
    end
    
    context 'with stdio configuration' do
      it 'validates missing command' do
        config = {
          "name" => "Stdio Test",
          "server_type" => "stdio",
          "server_config" => {
            "args" => ["--test"]
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Command is required for stdio server")
      end
      
      it 'checks command executability' do
        config = {
          "name" => "Stdio Test",
          "server_type" => "stdio",
          "server_config" => {
            "command" => "/nonexistent/command"
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Command not found or not executable: /nonexistent/command")
      end
      
      it 'accepts valid command' do
        config = {
          "name" => "Stdio Test",
          "server_type" => "stdio",
          "server_config" => {
            "command" => "echo" # Should exist on all systems
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be true
      end
    end
    
    context 'with HTTP/SSE configuration' do
      it 'validates missing endpoint/url' do
        config = {
          "name" => "HTTP Test",
          "server_type" => "http",
          "server_config" => {}
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Endpoint is required for http server")
      end
      
      it 'validates malformed URL' do
        config = {
          "name" => "HTTP Test",
          "server_type" => "http",
          "server_config" => {
            "endpoint" => "not-a-url"
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Invalid URL format: not-a-url")
      end
      
      it 'accepts valid HTTPS URL' do
        config = {
          "name" => "HTTP Test",
          "server_type" => "http",
          "server_config" => {
            "endpoint" => "https://api.example.com/mcp"
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be true
      end
    end
    
    context 'with WebSocket configuration' do
      it 'validates WebSocket URL' do
        config = {
          "name" => "WebSocket Test",
          "server_type" => "websocket",
          "server_config" => {
            "endpoint" => "https://example.com" # Should be wss://
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("WebSocket URL must use wss:// or ws:// protocol")
      end
      
      it 'accepts valid WebSocket URL' do
        config = {
          "name" => "WebSocket Test",
          "server_type" => "websocket",
          "server_config" => {
            "endpoint" => "wss://api.example.com/mcp"
          }
        }
        
        validator = McpConfigValidator.new(config)
        result = validator.validate
        
        expect(result[:valid]).to be true
      end
    end
  end
  
  describe '#test_connection' do
    let(:config) do
      {
        "name" => "Test Server",
        "server_type" => "http",
        "server_config" => {
          "endpoint" => "https://api.example.com/mcp"
        }
      }
    end
    
    it 'returns test results' do
      validator = McpConfigValidator.new(config)
      
      # Mock HTTP test
      allow(validator).to receive(:test_http_connection).and_return({
        success: true,
        message: "Connection successful",
        response_time: 150
      })
      
      result = validator.test_connection
      
      expect(result[:success]).to be true
      expect(result[:message]).to eq("Connection successful")
      expect(result[:response_time]).to eq(150)
    end
    
    it 'handles connection errors' do
      validator = McpConfigValidator.new(config)
      
      allow(validator).to receive(:test_http_connection).and_raise(StandardError, "Connection refused")
      
      result = validator.test_connection
      
      expect(result[:success]).to be false
      expect(result[:error]).to include("Connection refused")
    end
  end
end