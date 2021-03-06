class Project < ActiveRecord::Base

  has_many :tasks, dependent: :destroy

  belongs_to :user

  def as_json(options={})
    included = options[:include] || { tasks: {except: :project} }
    except = [:user, :user_id, :tasks].delete_if { |attr| included.include?(attr) }

    hash = super(except: except, include: included)
    hash['points'] = points
    hash['remaining_points'] = remaining_points
    hash['errors'] = errors.as_json if errors.present?

    hash
  end

  def calculate_points
    tasks.map(&:points).reduce(0, :+)
  end

  def calculate_remaining_points
    points - tasks.select(&:finished).map(&:points).reduce(0, :+)
  end
end
