require 'rails_helper'

describe 'Sprint Project requests' do
  describe 'DELETE /api/v1/sprint_projects/:id/sprint_project_tasks/:id' do
    it 'deletes a sprint project task and returns' do
      user = create :user
      project = create :project, user: user
      task = create :task, project: project
      sprint = create :sprint, user: user
      sp = create :sprint_project, sprint: sprint, project: project
      spt = create :sprint_project_task, sprint_project: sp, task: task

      delete(api_v1_sprint_project_sprint_project_task_url(sp, spt), params: {}, headers: authorization_headers(user))

      expect(response).to have_http_status :no_content
    end
  end
end

def valid_sprint_proj_task_params(project)
  {
    sprint_project: {
      project_id: project.id
    }
  }.to_json
end
