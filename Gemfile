source 'https://rubygems.org'

ruby '3.3.11'

gem 'rails', '~> 7.1.0'
gem 'puma', '~> 6.4'
gem 'pg', '~> 1.5'
gem 'sqlite3', '~> 1.4'

gem 'cancancan', '~> 3.5'
gem 'inherited_resources', '~> 1.14'

gem 'kaminari', '~> 1.2'
gem 'api-pagination', '~> 5.0'
gem 'ransack', '~> 4.0'

gem 'bcrypt', '~> 3.1'
gem 'devise', '~> 4.9'

gem 'jbuilder', '~> 2.11'  # only if needed by Rails defaults; remove if no .jbuilder views

# Boot/runtime
gem 'bootsnap', '~> 1.16', require: false
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

group :development, :test do
  gem 'byebug'
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'shoulda-matchers', '~> 6.0'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'json_spec', '~> 1.1'
  gem 'webmock', '~> 3.19'
  gem 'timecop', '~> 0.9'
end

group :development do
  gem 'listen', '~> 3.8'
end

group :test do
  gem 'capybara', '~> 3.39'
  gem 'selenium-webdriver', '~> 4.16'
  gem 'rails-controller-testing'
end
