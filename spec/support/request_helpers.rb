# frozen_string_literal: true

# Helper methods for request specs
module RequestHelpers
  def json_headers
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/json'
    }
  end

  def auth_headers(user = nil)
    user ||= create(:user)
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    {
      'Authorization' => "Bearer #{token}",
      **json_headers
    }
  end

  def post_json(path, params = {}, headers = {})
    post path, params: params.to_json, headers: json_headers.merge(headers)
  end

  def put_json(path, params = {}, headers = {})
    put path, params: params.to_json, headers: json_headers.merge(headers)
  end

  def patch_json(path, params = {}, headers = {})
    patch path, params: params.to_json, headers: json_headers.merge(headers)
  end

  def delete_json(path, params = {}, headers = {})
    delete path, params: params.to_json, headers: json_headers.merge(headers)
  end

  def json_response
    JSON.parse(response.body).with_indifferent_access
  end

  def expect_json_success(status = :ok)
    expect(response).to have_http_status(status)
    expect(response.content_type).to include('application/json')
    expect(json_response[:success]).to be true
  end

  def expect_json_error(status = :unprocessable_entity)
    expect(response).to have_http_status(status)
    expect(response.content_type).to include('application/json')
    expect(json_response[:error]).to be_present
  end

  def expect_validation_errors(*fields)
    expect_json_error
    fields.each do |field|
      expect(json_response[:errors]).to have_key(field.to_s)
    end
  end

  def sign_in_for_request(user = nil)
    user ||= create(:user)
    sign_in user
    user
  end

  # Helper for testing pagination
  def expect_paginated_response(resource_key = :data)
    expect(json_response).to have_key(resource_key)
    expect(json_response).to have_key(:pagination)
    expect(json_response[:pagination]).to include(:current_page, :total_pages, :total_count)
  end

  # Helper for testing API rate limiting
  def expect_rate_limited
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers).to include('Retry-After')
  end

  # Helper for CORS testing
  def expect_cors_headers
    expect(response.headers['Access-Control-Allow-Origin']).to be_present
    expect(response.headers['Access-Control-Allow-Methods']).to be_present
  end
end
