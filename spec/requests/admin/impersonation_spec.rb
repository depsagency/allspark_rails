require 'rails_helper'

RSpec.describe "Admin::Impersonations", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:another_user) { create(:user) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/impersonation" do
    context "when authenticated as admin" do
      it "returns http success" do
        get "/admin/impersonation"
        expect(response).to have_http_status(:success)
      end

      it "displays audit logs" do
        log = create(:impersonation_audit_log, 
                     impersonator: admin_user, 
                     impersonated_user: regular_user)
        get "/admin/impersonation"
        expect(response.body).to include(admin_user.display_name)
        expect(response.body).to include(regular_user.display_name)
      end
    end

    context "when not authenticated as admin" do
      before do
        sign_in regular_user
      end

      it "redirects with access denied" do
        get "/admin/impersonation"
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "POST /admin/impersonation/start" do
    context "with valid parameters" do
      it "starts impersonation session" do
        expect {
          post "/admin/impersonation/start", params: { user_id: regular_user.id }
        }.to change { ImpersonationAuditLog.count }.by(1)
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("impersonating")
      end

      it "creates audit log" do
        post "/admin/impersonation/start", params: { 
          user_id: regular_user.id,
          reason: "Testing purposes"
        }
        
        log = ImpersonationAuditLog.last
        expect(log.impersonator).to eq(admin_user)
        expect(log.impersonated_user).to eq(regular_user)
        expect(log.action).to eq('start')
        expect(log.reason).to eq('Testing purposes')
      end

      it "sets session data" do
        post "/admin/impersonation/start", params: { user_id: regular_user.id }
        
        expect(session[:impersonation]).to be_present
        expect(session[:impersonation]['original_user_id']).to eq(admin_user.id)
        expect(session[:impersonation]['impersonated_user_id']).to eq(regular_user.id)
      end
    end

    context "when trying to impersonate another admin" do
      let(:another_admin) { create(:user, :admin) }

      it "redirects with error" do
        post "/admin/impersonation/start", params: { user_id: another_admin.id }
        expect(response).to redirect_to(admin_impersonation_index_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user does not exist" do
      it "redirects with error" do
        post "/admin/impersonation/start", params: { user_id: 'non-existent' }
        expect(response).to redirect_to(admin_impersonation_index_path)
        expect(flash[:alert]).to include("not found")
      end
    end
  end

  describe "DELETE /admin/impersonation/stop" do
    context "when currently impersonating" do
      before do
        # Set up impersonation session
        session[:impersonation] = {
          'original_user_id' => admin_user.id,
          'impersonated_user_id' => regular_user.id,
          'audit_log_id' => create(:impersonation_audit_log, 
                                   impersonator: admin_user,
                                   impersonated_user: regular_user,
                                   ended_at: nil).id,
          'started_at' => Time.current.to_i,
          'ip_address' => '127.0.0.1'
        }
      end

      it "ends impersonation session" do
        delete "/admin/impersonation/stop"
        expect(response).to redirect_to(admin_impersonation_index_path)
        expect(flash[:notice]).to include("ended successfully")
        expect(session[:impersonation]).to be_nil
      end

      it "updates audit log" do
        audit_log_id = session[:impersonation]['audit_log_id']
        delete "/admin/impersonation/stop"
        
        log = ImpersonationAuditLog.find(audit_log_id)
        expect(log.ended_at).to be_present
      end
    end

    context "when not currently impersonating" do
      it "redirects with error" do
        delete "/admin/impersonation/stop"
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("not currently impersonating")
      end
    end
  end

  describe "security" do
    context "when not authenticated" do
      before do
        sign_out admin_user
      end

      it "requires authentication for index" do
        get "/admin/impersonation"
        expect(response).to redirect_to(new_user_session_path)
      end

      it "requires authentication for start" do
        post "/admin/impersonation/start", params: { user_id: regular_user.id }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "requires authentication for stop" do
        delete "/admin/impersonation/stop"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as regular user" do
      before do
        sign_in regular_user
      end

      it "denies access to admin endpoints" do
        get "/admin/impersonation"
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
