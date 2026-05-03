class Day < ActiveRecord::Base
  belongs_to :sprint
  has_many :day_tasks, dependent: :destroy
  has_many :tasks, through: :day_tasks
  validates :date, uniqueness: { scope: :sprint_id }

  def as_json(options={})
    included = options[:include] || {}
    except = [:sprint, :sprint_id].delete_if { |attr| included.include?(attr) }

    hash = super(except: except, include: {day_tasks: {include: {task: {include: {project: {except: :tasks}}}}}})
    hash['errors'] = errors.as_json if errors.present?

    hash
  end

  def update_points
    self.points = calculate_points
    self.finished_points = calculate_finished_points

    save
  end

  def calculate_points
    tasks.map(&:points).reduce(0, :+)
  end

  def calculate_finished_points
    tasks.select(&:finished).map(&:points).reduce(0, :+)
  end
end
