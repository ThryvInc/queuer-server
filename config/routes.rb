RailsApp::Application.routes.draw do
  namespace :api, :defaults => { :format => 'json' } do
    namespace :v1 do
      resource :session, :only => [:create]
      resources :users
      resources :projects do
        resources :tasks
      end
      resources :sprints do
        resources :sprint_projects do
          resources :sprint_project_tasks
        end
        resources :days do
          resources :day_tasks
        end
      end
      resources :sprint_projects do
        resources :sprint_project_tasks
      end
    end
  end
end
