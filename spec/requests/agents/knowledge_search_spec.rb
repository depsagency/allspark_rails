require 'rails_helper'

RSpec.describe "Agents::KnowledgeSearches", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/agents/knowledge_search/index"
      expect(response).to have_http_status(:success)
    end
  end

end
