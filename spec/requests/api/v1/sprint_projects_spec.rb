require 'rails_helper'

describe 'Sprint Project requests' do
  describe 'POST /api/v1/sprints/:id/sprint_projects' do
    it 'creates a sprint project and returns' do
      user = create :user
      project = create :project, user: user
      sprint = create :sprint, user: user

      post(api_v1_sprint_sprint_projects_url(sprint), params: valid_sprint_proj_params(project),
           headers: authorization_headers(user))

      expect(response).to have_http_status :created

      sprint_project = SprintProject.find(json['id'])
      expect(sprint_project.sprint_id).not_to be_nil
    end
  end

  describe 'GET /api/v1/sprints/:id/sprint_projects' do
    it 'gets sprint projects for the sprint' do
      user = create :user
      project = create :project, user: user
      sprint = create :sprint, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      sp = create :sprint_project, sprint: sprint, project: project
      spt = create :sprint_project_task, sprint_project: sp, task: task

      other_user = create :user, username: 'other'
      other_project = create :project, user: other_user
      other_sprint = create :sprint, user: other_user
      create :sprint_project, sprint: other_sprint, project: other_project

      get(api_v1_sprint_sprint_projects_url(sprint), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
      expect(json.count).to eq 1
      expect(json.first['project']['tasks']).to be_nil
      expect(json.first['sprint_project_tasks'].first['task']).not_to be_nil
      expect(json.first['sprint_project_tasks'].first['task']['project']).to be_nil
    end
  end

  describe 'GET /api/v1/sprint_projects/:id' do
    it 'gets sprint project for the user' do
      user = create :user
      project = create :project, user: user
      sprint = create :sprint, user: user
      sp = create :sprint_project, sprint: sprint, project: project

      get(api_v1_sprint_project_url(sp), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :ok
    end
  end
end

def valid_sprint_proj_params(project)
  {
    sprint_project: {
      project_id: project.id
    }
  }.to_json
end
