class Task < ActiveRecord::Base

  belongs_to :project, optional: true
  has_many :day_tasks, dependent: :destroy
  has_many :sprint_project_tasks, dependent: :destroy

  after_save :update_project_points, :update_day_points, :update_sprint_project_points

  def as_json(options={})
    included = options[:include] || {}
    except = [:project, :project_id].delete_if { |attr| included.include?(attr) }

    hash = super(:except => except)
    hash['errors'] = errors.as_json if errors.present?

    hash
  end

  def update_project_points
    project.points = project.calculate_points
    project.remaining_points = project.calculate_remaining_points

    project.save
  end

  def update_sprint_project_points
    sprint_project_tasks.each do |sprint_project_task|
      sprint_project_task.sprint_project.update_points
    end
  end

  def update_day_points
    day_tasks.each do |day_task|
      day_task.day.update_points
    end
  end
end
