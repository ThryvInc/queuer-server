FactoryBot.define do
  factory :day do
    sprint
    date { 1.day.from_now }
  end
end
