# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JsonRpcMessage, type: :model do
  describe '.request' do
    it 'creates a valid JSON-RPC 2.0 request with all parameters' do
      request = described_class.request(
        method: 'test_method',
        params: { key: 'value' },
        id: 'test-123'
      )
      
      expect(request).to eq({
        jsonrpc: '2.0',
        method: 'test_method',
        params: { key: 'value' },
        id: 'test-123'
      })
    end

    it 'creates a valid request with minimal parameters' do
      request = described_class.request(method: 'test_method')
      
      expect(request[:jsonrpc]).to eq('2.0')
      expect(request[:method]).to eq('test_method')
      expect(request[:id]).to be_present
      expect(request).not_to have_key(:params)
    end

    it 'generates a UUID if no ID is provided' do
      request = described_class.request(method: 'test_method')
      
      expect(request[:id]).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end

    it 'raises an error if method is missing' do
      expect {
        described_class.request(method: nil)
      }.to raise_error(ArgumentError, 'Method name is required')
    end

    it 'raises an error if method is not a string' do
      expect {
        described_class.request(method: 123)
      }.to raise_error(ArgumentError, 'Method must be a string')
    end

    it 'handles nil params correctly' do
      request = described_class.request(method: 'test', params: nil)
      expect(request).not_to have_key(:params)
    end
  end

  describe '.response' do
    it 'creates a valid response with result' do
      response = described_class.response(
        result: { data: 'test' },
        id: 'test-123'
      )
      
      expect(response).to eq({
        jsonrpc: '2.0',
        id: 'test-123',
        result: { data: 'test' }
      })
    end

    it 'creates a valid response with error' do
      response = described_class.response(
        error: { code: -32601, message: 'Method not found' },
        id: 'test-123'
      )
      
      expect(response).to eq({
        jsonrpc: '2.0',
        id: 'test-123',
        error: {
          code: -32601,
          message: 'Method not found'
        }
      })
    end

    it 'uses default error code if not provided' do
      response = described_class.response(
        error: { message: 'Something went wrong' },
        id: 'test-123'
      )
      
      expect(response[:error][:code]).to eq(-1)
    end

    it 'includes error data if provided' do
      response = described_class.response(
        error: { code: -32602, message: 'Invalid params', data: { field: 'name' } },
        id: 'test-123'
      )
      
      expect(response[:error][:data]).to eq({ field: 'name' })
    end

    it 'raises an error if ID is missing' do
      expect {
        described_class.response(result: 'test', id: nil)
      }.to raise_error(ArgumentError, 'ID is required for response')
    end

    it 'raises an error if both result and error are provided' do
      expect {
        described_class.response(result: 'test', error: { message: 'error' }, id: '123')
      }.to raise_error(ArgumentError, 'Cannot have both result and error')
    end

    it 'raises an error if neither result nor error are provided' do
      expect {
        described_class.response(id: '123')
      }.to raise_error(ArgumentError, 'Must have either result or error')
    end

    it 'raises an error if error is not a hash' do
      expect {
        described_class.response(error: 'string error', id: '123')
      }.to raise_error(ArgumentError, 'Error must be a hash')
    end

    it 'raises an error if error has no message' do
      expect {
        described_class.response(error: { code: -1 }, id: '123')
      }.to raise_error(ArgumentError, 'Error must have a message')
    end
  end

  describe '.valid_request?' do
    it 'returns true for valid request' do
      request = {
        jsonrpc: '2.0',
        method: 'test',
        id: '123'
      }
      
      expect(described_class.valid_request?(request)).to be true
    end

    it 'returns false for non-hash input' do
      expect(described_class.valid_request?('not a hash')).to be false
    end

    it 'returns false for wrong jsonrpc version' do
      request = { jsonrpc: '1.0', method: 'test' }
      expect(described_class.valid_request?(request)).to be false
    end

    it 'returns false for missing method' do
      request = { jsonrpc: '2.0' }
      expect(described_class.valid_request?(request)).to be false
    end

    it 'returns false for invalid params type' do
      request = { jsonrpc: '2.0', method: 'test', params: 'string' }
      expect(described_class.valid_request?(request)).to be false
    end

    it 'returns true for array params' do
      request = { jsonrpc: '2.0', method: 'test', params: [1, 2, 3] }
      expect(described_class.valid_request?(request)).to be true
    end
  end

  describe '.valid_response?' do
    it 'returns true for valid result response' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        result: 'success'
      }
      
      expect(described_class.valid_response?(response)).to be true
    end

    it 'returns true for valid error response' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        error: { code: -32601, message: 'Method not found' }
      }
      
      expect(described_class.valid_response?(response)).to be true
    end

    it 'returns false for response with both result and error' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        result: 'success',
        error: { code: -1, message: 'error' }
      }
      
      expect(described_class.valid_response?(response)).to be false
    end

    it 'returns false for invalid error structure' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        error: 'string error'
      }
      
      expect(described_class.valid_response?(response)).to be false
    end
  end

  describe '.parse_error' do
    it 'returns error information from response' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        error: { code: -32601, message: 'Method not found' }
      }
      
      error = described_class.parse_error(response)
      expect(error).to eq({ code: -32601, message: 'Method not found' })
    end

    it 'returns nil for response without error' do
      response = { jsonrpc: '2.0', id: '123', result: 'success' }
      
      expect(described_class.parse_error(response)).to be_nil
    end
  end

  describe '.parse_result' do
    it 'returns result from response' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        result: { data: 'test' }
      }
      
      result = described_class.parse_result(response)
      expect(result).to eq({ data: 'test' })
    end

    it 'returns nil for response without result' do
      response = {
        jsonrpc: '2.0',
        id: '123',
        error: { code: -1, message: 'error' }
      }
      
      expect(described_class.parse_result(response)).to be_nil
    end
  end

  describe 'edge cases' do
    it 'handles nil params correctly in request' do
      request = described_class.request(method: 'test', params: nil, id: '123')
      expect(request).not_to have_key(:params)
    end

    it 'handles empty string method as invalid' do
      expect {
        described_class.request(method: '')
      }.to raise_error(ArgumentError, 'Method name is required')
    end

    it 'preserves nil result in response' do
      response = described_class.response(result: nil, id: '123')
      expect(response).to have_key(:result)
      expect(response[:result]).to be_nil
    end
  end
end