class Sprint < ActiveRecord::Base
  paginates_per 8

  belongs_to :user
  has_many :days
  has_many :sprint_projects
  has_many :projects, through: :sprint_projects

  def as_json(options={})
    included = options[:include] || { sprint_projects: {include: {project: {except: :tasks}, 
                                                                  sprint_project_tasks: {include: {task: {except: :project}}}}},
                                      days: { except: [:tasks, :day_tasks]} }
    excepted = options[:except] || [:user, :user_id, :sprint_projects, :projects, :days].delete_if { |attr| included.include?(attr) }

    hash = super(except: excepted, include: included)
    
    hash['points'] = points
    hash['finished_points'] = finished_points
    hash['errors'] = errors.as_json if errors.present?

    hash
  end

  def points
    days.map(&:points).reduce(0, :+)
  end

  def finished_points
    days.map(&:finished_points).reduce(0, :+)
  end
end
