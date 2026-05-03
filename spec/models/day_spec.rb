require 'rails_helper'

describe Day, type: :model do
  subject { build(:day) }
  it { is_expected.to validate_uniqueness_of(:date).scoped_to(:sprint_id) }

  describe 'points' do
    it 'calculates points correctly' do
      day = create :day
      task = create :task 
      finished_task = create :task, finished: true
      
      day_task = create :day_task, task: task, day: day
      day.reload
      expect(day.points).to eq 1

      day_finished_task = create :day_task, task: finished_task, day: day

      expect(day_task).not_to be_nil
      expect(day_finished_task).not_to be_nil

      expect(day_task.task.points).to eq 1
      expect(day_finished_task.task.points).to eq 1

      expect(day_task.day.id).to eq day.id
      expect(day_finished_task.day.id).to eq day.id

      expect(day.day_tasks.count).to eq 2
      expect(day.tasks.count).to eq 2

      expect(day.tasks).to eq [day_task.task, day_finished_task.task]

      expect(day.tasks.map(&:points)).to eq [1,1]

      expect(day.calculate_points).to eq 2
      expect(day.calculate_finished_points).to eq 1

      expect(day.points).to eq 2
      expect(day.finished_points).to eq 1
    end
  end

end
