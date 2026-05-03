require 'rails_helper'

describe 'Session requests' do
  describe 'POST /api/v1/sessions' do
    it 'creates a session and returns JSON' do
      create :user

      session_attributes = {
        username: 'eschrock',
        password: 'password'
      }.to_json

      post(api_v1_session_url, params: session_attributes, headers: accept_headers)

      expect(response).to have_http_status :ok
      expect(json['api_key']).not_to be_nil
    end

    it 'does not login for bad username' do
      user = create :user

      session_attributes = {
        username: user.username + "_wrong",
        password: 'password'
      }.to_json

      post(api_v1_session_url, params: session_attributes, headers: accept_headers)

      expect(response).to have_http_status :unauthorized
    end

    it 'does not login for bad password' do
      user = create :user

      session_attributes = {
        username: user.username,
        password: 'wrong'
      }.to_json

      post(api_v1_session_url, params: session_attributes, headers: accept_headers)

      expect(response).to have_http_status :unauthorized
    end
  end
end
