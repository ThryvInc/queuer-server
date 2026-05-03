class DayTask < ActiveRecord::Base
  belongs_to :day
  belongs_to :task
  belongs_to :next, class_name: 'DayTask', optional: true
  belongs_to :previous, class_name: 'DayTask', optional: true

  validates :task_id, uniqueness: { scope: :day_id }

  after_create :update_day_points
  after_destroy :update_day_points

  def as_json(options={})
    included = options[:include] || {}
    except = [:day, :day_id].delete_if { |attr| included.include?(attr) }

    hash = super(except: except, include: {task: {include: {project: {except: :tasks}}}})
    hash['errors'] = errors.as_json if errors.present?

    hash
  end

  def update_day_points
    day.update_points
  end
end
