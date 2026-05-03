require 'rails_helper'

describe 'User requests' do
  describe 'POST /api/v1/users' do
    it 'creates a user and returns JSON' do
      new_user_attributes = {
        user: {
          username: 'eschrock',
          password: 'password'
        }
      }.to_json

      post(api_v1_users_url, params: new_user_attributes, headers: accept_headers)

      expect(response).to have_http_status :created
      expect(json['api_key']).not_to be_nil
    end

    it 'does not create duplicate users' do
      user = create :user

      new_user_attributes = {
        user: {
          username: user.username,
          password: 'new'
        }
      }.to_json

      post(api_v1_users_url, params: new_user_attributes, headers: accept_headers)

      expect(User.count).to eq 1
      expect(response).to have_http_status :unprocessable_entity
    end
  end
end
