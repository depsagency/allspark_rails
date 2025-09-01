require 'rails_helper'

RSpec.describe "ClaudeCode::Sessions", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/claude_code/sessions/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/claude_code/sessions/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/claude_code/sessions/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/claude_code/sessions/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/claude_code/sessions/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/claude_code/sessions/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/claude_code/sessions/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /start" do
    it "returns http success" do
      get "/claude_code/sessions/start"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /stop" do
    it "returns http success" do
      get "/claude_code/sessions/stop"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reset" do
    it "returns http success" do
      get "/claude_code/sessions/reset"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /export" do
    it "returns http success" do
      get "/claude_code/sessions/export"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /review" do
    it "returns http success" do
      get "/claude_code/sessions/review"
      expect(response).to have_http_status(:success)
    end
  end

end
