FactoryBot.define do
  factory :sprint do
    user
    start_date { 1.day.from_now }
  end
end
