# frozen_string_literal: true

# Helper methods for controller specs
module ControllerHelpers
  def sign_in_user(user = nil)
    user ||= create(:user)
    sign_in user
    user
  end

  def sign_in_admin
    admin = create(:user, :admin)
    sign_in admin
    admin
  end

  def json_response
    JSON.parse(response.body)
  end

  def expect_json_response(status = :ok)
    expect(response).to have_http_status(status)
    expect(response.content_type).to include('application/json')
  end

  def expect_redirect_with_flash(path, flash_type, message = nil)
    expect(response).to redirect_to(path)
    expect(flash[flash_type]).to be_present
    expect(flash[flash_type]).to include(message) if message
  end

  def expect_unauthorized
    expect(response).to have_http_status(:unauthorized)
  end

  def expect_forbidden
    expect(response).to have_http_status(:forbidden)
  end

  def expect_not_found
    expect(response).to have_http_status(:not_found)
  end
end
