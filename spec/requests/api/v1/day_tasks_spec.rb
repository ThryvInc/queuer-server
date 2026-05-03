require 'rails_helper'

describe 'Day task requests' do
  describe 'POST /api/v1/sprints/:id/days/:id/day_tasks' do
    it 'creates a sprint and returns' do
      user = create :user
      project = create :project, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      day = create :day, sprint: sprint

      post(api_v1_sprint_day_day_tasks_url(sprint, day), params: valid_day_task_params(task), headers: authorization_headers(user))

      expect(response).to have_http_status :created
    end
  end

  describe 'GET /api/v1/sprints/:id/days/:id/day_tasks' do
    it 'gets sprint for the user' do
      user = create :user
      project = create :project, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      day = create :day, sprint: sprint
      create :day_task, day: day, task: task

      get(api_v1_sprint_day_day_tasks_url(sprint, day), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
    end
  end
end

def valid_day_task_params(task)
  {
    day_task: {
      task_id: task.id
    }
  }.to_json
end
