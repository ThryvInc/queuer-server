FactoryBot.define do
  factory :user do
    api_key { SecureRandom.hex(20).encode('UTF-8') }
    sequence(:username) { |n| "eschrock#{n == 1 ? '' : n}" }
    password { "password" }
    admin { true }
  end
end
