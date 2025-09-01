require 'rails_helper'

RSpec.describe McpConfigurationsController, type: :controller do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end
  
  describe 'GET #index' do
    let!(:user_config) { create(:mcp_configuration, owner: user, name: "My Config") }
    let!(:other_config) { create(:mcp_configuration, name: "Other Config") }
    
    it 'returns user configurations' do
      get :index
      
      expect(response).to be_successful
      expect(assigns(:configurations)).to include(user_config)
      expect(assigns(:configurations)).not_to include(other_config)
    end
    
    it 'loads templates' do
      get :index
      
      expect(assigns(:templates)).not_to be_nil
      expect(assigns(:templates)).to be_a(Hash)
    end
    
    it 'responds to JSON' do
      get :index, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json["configurations"]).to be_an(Array)
      expect(json["configurations"].first["name"]).to eq("My Config")
    end
  end
  
  describe 'GET #new' do
    it 'builds new configuration' do
      get :new
      
      expect(response).to be_successful
      expect(assigns(:configuration)).to be_a_new(McpConfiguration)
    end
    
    it 'loads templates' do
      get :new
      
      expect(assigns(:templates)).not_to be_nil
    end
    
    context 'with template parameter' do
      it 'pre-fills from template' do
        get :new, params: { template: "linear" }
        
        config = assigns(:configuration)
        expect(config.server_type).to eq("stdio")
      end
    end
  end
  
  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          mcp_configuration: {
            name: "New Config",
            server_type: "http",
            server_config: {
              endpoint: "https://api.test.com"
            }
          }
        }
      end
      
      it 'creates configuration' do
        expect {
          post :create, params: valid_params
        }.to change(McpConfiguration, :count).by(1)
        
        config = McpConfiguration.last
        expect(config.owner).to eq(user)
        expect(config.name).to eq("New Config")
      end
      
      it 'redirects to index' do
        post :create, params: valid_params
        
        expect(response).to redirect_to(mcp_configurations_path)
        expect(flash[:notice]).to be_present
      end
      
      it 'responds to JSON' do
        post :create, params: valid_params, format: :json
        
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("New Config")
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          mcp_configuration: {
            name: "",
            server_type: "invalid"
          }
        }
      end
      
      it 'does not create configuration' do
        expect {
          post :create, params: invalid_params
        }.not_to change(McpConfiguration, :count)
      end
      
      it 'renders new template' do
        post :create, params: invalid_params
        
        expect(response).to render_template(:new)
        expect(assigns(:configuration).errors).not_to be_empty
      end
    end
    
    context 'from template' do
      let(:template_params) do
        {
          mcp_configuration: {
            name: "My Linear",
            template_key: "linear",
            template_params: {
              LINEAR_API_KEY: "test123"
            }
          }
        }
      end
      
      it 'creates from template' do
        post :from_template, params: template_params
        
        config = McpConfiguration.last
        expect(config.name).to eq("My Linear")
        expect(config.server_type).to eq("stdio")
        expect(config.metadata["template_key"]).to eq("linear")
      end
    end
  end
  
  describe 'GET #edit' do
    let(:configuration) { create(:mcp_configuration, owner: user) }
    
    it 'loads configuration' do
      get :edit, params: { id: configuration.id }
      
      expect(response).to be_successful
      expect(assigns(:configuration)).to eq(configuration)
    end
    
    it 'prevents editing other user configurations' do
      other_config = create(:mcp_configuration)
      
      expect {
        get :edit, params: { id: other_config.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
  
  describe 'PATCH #update' do
    let(:configuration) { create(:mcp_configuration, owner: user, name: "Old Name") }
    
    context 'with valid parameters' do
      let(:update_params) do
        {
          id: configuration.id,
          mcp_configuration: {
            name: "New Name"
          }
        }
      end
      
      it 'updates configuration' do
        patch :update, params: update_params
        
        configuration.reload
        expect(configuration.name).to eq("New Name")
      end
      
      it 'redirects to index' do
        patch :update, params: update_params
        
        expect(response).to redirect_to(mcp_configurations_path)
      end
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:configuration) { create(:mcp_configuration, owner: user) }
    
    it 'destroys configuration' do
      expect {
        delete :destroy, params: { id: configuration.id }
      }.to change(McpConfiguration, :count).by(-1)
    end
    
    it 'redirects to index' do
      delete :destroy, params: { id: configuration.id }
      
      expect(response).to redirect_to(mcp_configurations_path)
      expect(flash[:notice]).to be_present
    end
  end
  
  describe 'PATCH #toggle' do
    let(:configuration) { create(:mcp_configuration, owner: user, enabled: true) }
    
    it 'toggles enabled state' do
      patch :toggle, params: { id: configuration.id }
      
      configuration.reload
      expect(configuration.enabled).to be false
    end
    
    it 'responds to JSON' do
      patch :toggle, params: { id: configuration.id }, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json["enabled"]).to be false
    end
  end
  
  describe 'POST #test' do
    let(:configuration) { create(:mcp_configuration, owner: user) }
    
    it 'tests configuration' do
      allow_any_instance_of(McpConfigValidator).to receive(:test_connection).and_return({
        success: true,
        message: "Connection successful"
      })
      
      post :test, params: { id: configuration.id }, format: :json
      
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to eq("Connection successful")
    end
  end
end