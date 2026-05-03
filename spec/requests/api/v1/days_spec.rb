require 'rails_helper'

describe 'Day requests' do
  describe 'POST /api/v1/sprints/:id/days' do
    it 'creates a day and returns' do
      user = create :user
      sprint = create :sprint, user: user

      post(api_v1_sprint_days_url(sprint), params: valid_day_params, headers: authorization_headers(user))

      expect(response).to have_http_status :created
    end
  end

  describe 'GET /api/v1/sprints/:id/days' do
    it 'gets days for the sprint' do
      user = create :user
      sprint = create :sprint, user: user
      create_list :day, 3, sprint: sprint

      get(api_v1_sprint_days_url(sprint), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
    end

    it 'is unauthorized when other user' do
      user = create :user
      sprint = create :sprint, user: user
      other_user = create :user, username: 'other'

      get(api_v1_sprint_days_url(sprint), params: {}, headers: authorization_headers(other_user))

      expect(response).to have_http_status :unauthorized
    end
  end

  describe 'GET /api/v1/sprints/:id/days/:id' do
    it 'gets day for the sprint' do
      user = create :user
      sprint = create :sprint, user: user
      create_list :day, 3, sprint: sprint

      get(api_v1_sprint_day_url(sprint, Day.last), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
    end
  end
end

def valid_day_params
  {
    day: {
      date: 2.days.from_now
    }
  }.to_json
end
