require 'rails_helper'

describe 'Task requests' do
  describe 'POST /api/v1/projects/:id/tasks' do
    it 'creates a task and returns JSON' do
      user = create :user
      project = create :project, user_id: user.id

      new_task_attributes = {
        task: {
          name: 'Be awesome',
          finished: false,
          points: 2,
          order: 1
        }
      }.to_json

      post(api_v1_project_tasks_url(project), params: new_task_attributes, headers: authorization_headers(user))

      project.reload

      expect(response).to have_http_status :created
      expect(project.points).to eq 2
    end
  end

  describe 'GET /tasks' do
    it 'gets tasks for the project' do
      user = create :user
      other_user = create :user, username: 'other'
      project = create :project, user: user
      task = create :task, project: project
      create :task
      sprint = create :sprint, user: user
      day = create :day, sprint: sprint
      create :day_task, day: day, task: task
      create :sprint_project, sprint: sprint, project: project

      get(api_v1_project_tasks_url(project), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
      expect(json.count).to eq 1
    end

    it 'is unauthorized when no user' do
      user = create :user
      project = create :project, user_id: user.id

      get(api_v1_project_tasks_url(project), params: {}, headers: accept_headers)

      expect(response).to have_http_status :unauthorized
    end

    it 'is unauthorized when no user' do
      user = create :user
      other_user = create :user, username: 'other'
      project = create :project, user_id: user.id

      get(api_v1_project_tasks_url(project), params: {}, headers: authorization_headers(other_user))

      expect(response).to have_http_status :unauthorized
    end
  end
end
