require 'rails_helper'

describe 'Sprint requests' do
  describe 'POST /api/v1/sprints' do
    it 'creates a sprint and returns' do
      post(api_v1_sprints_url, params: valid_sprint_params, headers: authorization_headers)

      expect(response).to have_http_status :created
    end
  end

  describe 'GET /api/v1/sprints' do
    it 'gets sprints for the user' do
      user = create :user
      other_user = create :user, username: 'other'
      project = create :project, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      create :sprint, user: other_user
      day = create :day, sprint: sprint
      create :day_task, day: day, task: task
      create :sprint_project, sprint: sprint, project: project

      get(api_v1_sprints_url, params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
      expect(json.count).to eq 1
      expect(json.first['days']).to be_nil
    end

    it 'orders by start_date' do
      user = create :user
      other_user = create :user, username: 'other'
      
      project = create :project, user: user
      task = create :task, project: project
      
      sprint = create :sprint, user: user
      latest_sprint = create :sprint, user: user, start_date: 2.days.from_now
      first_sprint = create :sprint, user: user, start_date: 1.day.ago
      create :sprint, user: other_user
      
      day = create :day, sprint: sprint
      create :day_task, day: day, task: task
      create :sprint_project, sprint: sprint, project: project

      get(api_v1_sprints_url, params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
      expect(json.count).to eq 3
      expect(json.first['id']).to eq latest_sprint.id
      expect(json.third['id']).to eq first_sprint.id
    end

    it 'paginates sprints' do
      user = create :user
      other_user = create :user, username: 'other'
      project = create :project, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      sprints = create_list :sprint, 9, user: user
      create :sprint, user: other_user
      day = create :day, sprint: sprint
      create :day_task, day: day, task: task
      create :sprint_project, sprint: sprint, project: project

      get(api_v1_sprints_url, params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
      expect(json.count).to eq 8
    end

    it 'is unauthorized when no user' do
      user = create :user
      create :sprint, user: user

      get(api_v1_sprints_url, params: {}, headers: accept_headers)

      expect(response).to have_http_status :unauthorized
    end
  end

  describe 'GET /api/v1/sprints/:id' do
    it 'gets the sprint for the user' do
      user = create :user
      other_user = create :user, username: 'other'
      project = create :project, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      create :sprint, user: other_user
      day = create :day, sprint: sprint
      create :day_task, day: day, task: task
      create :sprint_project, sprint: sprint, project: project

      get(api_v1_sprint_url(sprint), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
      expect(json['days'].count).to eq 1
      expect(json['sprint_projects'].first['project']['points']).to eq 1
      expect(json['days'].first['points']).to eq 1
    end

    it 'is unauthorized when no user' do
      user = create :user
      sprint = create :sprint, user: user
      other_user = create :user, username: 'other'

      get(api_v1_sprints_url(sprint), params: {}, headers: accept_headers)

      expect(response).to have_http_status :unauthorized
    end

    it 'is unauthorized when other user' do
      user = create :user
      sprint = create :sprint, user: user
      other_user = create :user, username: 'other'

      get(api_v1_sprint_url(sprint), params: {}, headers: authorization_headers(other_user))

      expect(response).to have_http_status :unauthorized
    end
  end
end

def valid_sprint_params
  {
    sprint: {
      start_date: 2.days.from_now
    }
  }.to_json
end
