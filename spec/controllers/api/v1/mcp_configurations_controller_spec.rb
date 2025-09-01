require 'rails_helper'

RSpec.describe Api::V1::McpConfigurationsController, type: :controller do
  let(:user) { create(:user) }
  let(:api_key) { "test_api_key_123" }
  
  before do
    # Mock API authentication
    allow(controller).to receive(:authenticate_api!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
  end
  
  describe 'GET #index' do
    let!(:config1) { create(:mcp_configuration, owner: user, name: "Config 1") }
    let!(:config2) { create(:mcp_configuration, owner: user, name: "Config 2", enabled: false) }
    let!(:other_config) { create(:mcp_configuration, name: "Other Config") }
    
    it 'returns user configurations as JSON' do
      get :index, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      
      expect(json).to be_an(Array)
      expect(json.length).to eq(2)
      
      names = json.map { |c| c["name"] }
      expect(names).to include("Config 1", "Config 2")
      expect(names).not_to include("Other Config")
    end
    
    it 'includes enabled status' do
      get :index, format: :json
      
      json = JSON.parse(response.body)
      config1_json = json.find { |c| c["name"] == "Config 1" }
      config2_json = json.find { |c| c["name"] == "Config 2" }
      
      expect(config1_json["enabled"]).to be true
      expect(config2_json["enabled"]).to be false
    end
  end
  
  describe 'GET #show' do
    let(:configuration) { create(:mcp_configuration, owner: user) }
    
    it 'returns configuration details' do
      get :show, params: { id: configuration.id }, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      
      expect(json["id"]).to eq(configuration.id)
      expect(json["name"]).to eq(configuration.name)
      expect(json["server_type"]).to eq(configuration.server_type)
      expect(json["server_config"]).to be_present
    end
    
    it 'returns 404 for other user configuration' do
      other_config = create(:mcp_configuration)
      
      get :show, params: { id: other_config.id }, format: :json
      
      expect(response).to have_http_status(:not_found)
    end
  end
  
  describe 'POST #create' do
    let(:valid_params) do
      {
        mcp_configuration: {
          name: "API Config",
          server_type: "http",
          server_config: {
            endpoint: "https://api.example.com/mcp",
            headers: { "X-API-Key" => "secret" }
          },
          enabled: true
        }
      }
    end
    
    it 'creates configuration' do
      expect {
        post :create, params: valid_params, format: :json
      }.to change(McpConfiguration, :count).by(1)
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json["name"]).to eq("API Config")
      expect(json["server_type"]).to eq("http")
    end
    
    it 'returns errors for invalid params' do
      invalid_params = {
        mcp_configuration: {
          name: "",
          server_type: "invalid"
        }
      }
      
      post :create, params: invalid_params, format: :json
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      
      expect(json["errors"]).to be_present
      expect(json["errors"]["name"]).to include("can't be blank")
      expect(json["errors"]["server_type"]).to include("is not included in the list")
    end
  end
  
  describe 'PATCH #update' do
    let(:configuration) { create(:mcp_configuration, owner: user, name: "Old Name") }
    
    it 'updates configuration' do
      patch :update, params: {
        id: configuration.id,
        mcp_configuration: { name: "New Name" }
      }, format: :json
      
      expect(response).to be_successful
      
      configuration.reload
      expect(configuration.name).to eq("New Name")
    end
    
    it 'returns updated configuration' do
      patch :update, params: {
        id: configuration.id,
        mcp_configuration: { enabled: false }
      }, format: :json
      
      json = JSON.parse(response.body)
      expect(json["enabled"]).to be false
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:configuration) { create(:mcp_configuration, owner: user) }
    
    it 'destroys configuration' do
      expect {
        delete :destroy, params: { id: configuration.id }, format: :json
      }.to change(McpConfiguration, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end
  
  describe 'POST #test' do
    it 'tests configuration' do
      test_params = {
        mcp_configuration: {
          name: "Test Config",
          server_type: "http",
          server_config: {
            endpoint: "https://api.example.com/mcp"
          }
        }
      }
      
      # Mock validator
      validator = instance_double(McpConfigValidator)
      allow(McpConfigValidator).to receive(:new).and_return(validator)
      allow(validator).to receive(:validate).and_return({ valid: true, errors: [] })
      allow(validator).to receive(:test_connection).and_return({
        success: true,
        message: "Connection successful",
        response_time: 123
      })
      
      post :test, params: test_params, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      
      expect(json["success"]).to be true
      expect(json["message"]).to eq("Connection successful")
      expect(json["response_time"]).to eq(123)
    end
    
    it 'returns validation errors' do
      invalid_params = {
        mcp_configuration: {
          name: "",
          server_type: "invalid"
        }
      }
      
      post :test, params: invalid_params, format: :json
      
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to be_present
    end
  end
  
  describe 'GET #for_session' do
    let!(:user_config) { create(:mcp_configuration, owner: user, enabled: true) }
    let!(:disabled_config) { create(:mcp_configuration, owner: user, enabled: false) }
    
    it 'returns aggregated configuration for Claude Code session' do
      get :for_session, params: { session_id: "test-session-123" }, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      
      expect(json["servers"]).to be_an(Array)
      expect(json["servers"].length).to eq(1) # Only enabled config
      expect(json["servers"].first["name"]).to eq(user_config.name)
    end
    
    context 'with instance parameter' do
      let(:instance) { create(:instance) if defined?(Instance) }
      let!(:instance_config) { create(:mcp_configuration, owner: instance, enabled: true) if instance }
      
      it 'includes instance configurations' do
        skip "Instance not defined" unless defined?(Instance)
        
        get :for_session, params: {
          session_id: "test-session-123",
          instance_id: instance.id
        }, format: :json
        
        json = JSON.parse(response.body)
        server_names = json["servers"].map { |s| s["name"] }
        
        expect(server_names).to include(user_config.name)
        expect(server_names).to include(instance_config.name)
      end
    end
  end
end