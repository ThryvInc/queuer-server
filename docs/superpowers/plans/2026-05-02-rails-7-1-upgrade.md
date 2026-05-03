# Rails 4.2 → 7.1 + Ruby 2.3 → 3.3 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the queuer-server Rails JSON API from Rails 4.2.7.1 / Ruby 2.3.1 to Rails 7.1 / Ruby 3.3.x so it can deploy on the heroku-22 or heroku-24 stack.

**Architecture:** Step-by-step Rails minor-version upgrade (4.2 → 5.0 → 5.1 → 5.2 → 6.0 → 6.1 → 7.0 → 7.1) with Ruby bumps interleaved at the points each Rails version requires them. Each phase ends with a green test suite and a checkpoint commit. Dependency replacements (dead/incompatible gems) are addressed up front in Phase 0 so we don't trip over them mid-upgrade. The `simple_admin` gem is replaced with `activeadmin` because the upstream is unmaintained and currently broken (git:// fetch).

**Tech Stack:** Rails 7.1, Ruby 3.3, Postgres, Puma, RSpec 6, FactoryBot, CanCanCan, ActiveAdmin, Heroku-22 / Heroku-24 stack.

---

## Ground rules for every phase

1. **Tests are the safety net.** Don't write new TDD tests for the upgrade itself — the existing `spec/` suite is what tells you a phase succeeded. Phase 0 first ensures it actually runs and passes.
2. **One Rails minor at a time.** Never skip a minor (e.g. 5.0 → 5.2 directly). Each minor's deprecation warnings become the next minor's removals.
3. **Use the dual-boot pattern within each phase if helpful** (`Gemfile` + `Gemfile.next`), but for this codebase's size it's optional. The plan below upgrades in-place per phase.
4. **Run after every change:** `bundle install`, `bin/rails app:update` (accepting/diffing each prompt — do NOT blindly say "Y to all"), `bundle exec rspec`, then `bundle exec rails s` smoke test.
5. **Commit at every checkpoint marked "Commit".** Each phase ends with a tag (`pre-rails-5.0`, `post-rails-5.0`, etc.) so rollback is `git reset --hard <tag>`.
6. **`bin/rails app:update` will offer to overwrite files** — review every diff. In particular, do NOT let it overwrite `config/routes.rb`, `app/controllers/application_controller.rb`, or anything in `app/models/` or `config/initializers/` unless the diff is genuinely an improvement. DO let it create new files (`config/initializers/new_framework_defaults_*.rb`, `bin/setup`, etc.).
7. **Heroku deployment is the final phase.** Don't deploy until everything is green locally — the staging dyno is for verifying the platform jump, not for finding upgrade bugs.

---

## Phase 0 — Pre-flight

**Goal:** Get the existing test suite running cleanly on the current Rails 4.2 codebase, replace dead/broken dependencies, and create a clean baseline.

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`
- Create: `.tool-versions` (or update `.ruby-version`)
- Create: `Procfile`
- Modify: `app/admin/projects.rb`, `app/admin/tasks.rb`, `app/admin/users.rb` (migrate to ActiveAdmin DSL)
- Delete: `lib/openshift_secret_generator.rb` (OpenShift artifact, no longer needed on Heroku)
- Modify: `config/initializers/secret_token.rb`, `config/initializers/session_store.rb`

- [ ] **Step 0.1: Tag current state**

```bash
git tag pre-upgrade-baseline
git push origin pre-upgrade-baseline
```

- [ ] **Step 0.2: Bump Ruby to 2.4.10** (last Ruby that Rails 4.2 fully supports; Ruby 2.3 has known issues with newer OpenSSL/RubyGems).

Update `.ruby-version`:

```
2.4.10
```

Add `ruby '2.4.10'` to `Gemfile` after the `source` line.

```bash
asdf install ruby 2.4.10  # or rbenv install 2.4.10
gem install bundler -v '~> 1.17.3'  # last bundler 1.x
bundle install
```

Expected: `bundle install` fails on the `git://` URL for `simple_admin`. That's the next step.

- [ ] **Step 0.3: Replace `simple_admin` with `activeadmin`**

In `Gemfile`, remove:

```ruby
gem 'simple_admin', :git => 'git://github.com/jeffrafter/simple_admin.git'
gem 'formtastic'
```

`simple_admin` is unmaintained and the `git://` protocol was disabled by GitHub in 2022 — `bundle install` fails outright on the current Gemfile. ActiveAdmin is the de-facto replacement, depends on Formtastic transitively, and works on Rails 4.2 through 7.x.

Add:

```ruby
gem 'activeadmin', '~> 1.4'  # last version compatible with Rails 4.2
gem 'devise', '~> 4.2'        # already present; activeadmin uses devise
```

Run:

```bash
bundle install
bundle exec rails generate active_admin:install
bundle exec rake db:migrate
```

Then port `app/admin/projects.rb`, `app/admin/tasks.rb`, `app/admin/users.rb` from SimpleAdmin DSL to ActiveAdmin DSL. Read each file and write the equivalent `ActiveAdmin.register Project do … end` block. Remove the SimpleAdmin mount in `config/routes.rb`:

```ruby
# Remove:
mount SimpleAdmin::Engine => '/admin', :as => :simple_admin
# ActiveAdmin's install generator already added: ActiveAdmin.routes(self)
```

- [ ] **Step 0.4: Replace dead/incompatible test gems**

In `Gemfile` `:test` group, replace:

```ruby
gem 'capybara-webkit', '>= 1.2.0'   # remove — Qt5 dependency, unbuildable on modern OSes
gem 'cancan'                        # remove — replaced by cancancan below
gem 'factory_girl_rails'            # remove — renamed
gem 'formulaic'                     # remove — unmaintained since 2017
```

With:

```ruby
gem 'cancancan', '~> 2.3'              # in main group, replaces cancan
gem 'factory_bot_rails', '~> 4.11'     # last version compatible with Rails 4.2
gem 'capybara', '~> 3.0'               # replaces capybara-webkit
# (no replacement needed for formulaic — it's only used by feature specs that don't exist)
```

In every spec file, find/replace `FactoryGirl` → `FactoryBot`. Search command:

```bash
grep -rl FactoryGirl spec/
```

Update `spec/rails_helper.rb`:

```ruby
# Remove:
# Capybara.javascript_driver = :webkit
# Add:
Capybara.javascript_driver = :selenium_chrome_headless
```

- [ ] **Step 0.5: Drop `rails_12factor`**

It's a no-op in Rails 5+, and we're going to upgrade soon. Removing now means one less moving part.

```ruby
# Remove from Gemfile:
gem 'rails_12factor', group: :production
```

- [ ] **Step 0.6: Replace OpenShift secret generator with plain ENV**

`lib/openshift_secret_generator.rb` is OpenShift-specific. On Heroku we use `SECRET_KEY_BASE` (already set on every Heroku app).

Replace `config/initializers/secret_token.rb` entirely with:

```ruby
RailsApp::Application.config.secret_key_base = ENV['SECRET_KEY_BASE'] || 'development_secret_replace_me'
```

Replace `config/initializers/session_store.rb` with:

```ruby
RailsApp::Application.config.session_store :cookie_store, key: '_railsapp_session'
```

Delete `lib/openshift_secret_generator.rb`.

- [ ] **Step 0.7: Add Procfile and switch Unicorn → Puma**

Heroku now defaults to Puma and Puma is what every Rails generator scaffolds. Switch now so we have one less change to make on Rails 5.

In `Gemfile`, replace:

```ruby
gem 'unicorn'
```

With:

```ruby
gem 'puma', '~> 3.12'   # last Puma compatible with Rails 4.2 / Ruby 2.4
```

Create `Procfile`:

```
web: bundle exec puma -C config/puma.rb
```

Create `config/puma.rb`:

```ruby
workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
```

- [ ] **Step 0.8: Lock dev/test DB to Postgres**

Right now dev/test use SQLite and prod uses Postgres. This will bite us on Rails 5+ when Postgres-only column types appear. Switch `config/database.yml` to Postgres for all envs (keeps prod and dev consistent):

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: queuer_development

test:
  <<: *default
  database: queuer_test

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
```

Remove `gem 'sqlite3'` from the `:test` group of the Gemfile. Then:

```bash
bundle install
bundle exec rake db:create db:schema:load
RAILS_ENV=test bundle exec rake db:create db:schema:load
```

- [ ] **Step 0.9: Run the full suite — phase gate**

```bash
bundle exec rspec
```

Expected: all green. If anything fails, fix it now — the Rails upgrade phases assume a green starting point. Likely failures:
- FactoryGirl → FactoryBot rename you missed
- Capybara driver references
- ActiveAdmin route changes (admin specs may reference old `/admin/...` paths)

- [ ] **Step 0.10: Commit and tag**

```bash
git add -A
git commit -m "chore: pre-upgrade dependency cleanup (Ruby 2.4, ActiveAdmin, Puma, Postgres)"
git tag phase-0-complete
```

---

## Phase 1 — Rails 4.2 → 5.0

**Goal:** Land on Rails 5.0.7.2 with all tests green.

**Files:**
- Modify: `Gemfile`
- Modify: `app/controllers/api/v1/api_controller.rb` (`before_filter` → `before_action`)
- Modify: `app/models/*.rb` (`belongs_to` review for required-by-default)
- Modify: `db/migrate/*.rb` (add migration version suffixes)
- Modify: `config/application.rb`
- Generated: `config/initializers/new_framework_defaults.rb`

- [ ] **Step 1.1: Bump Rails**

```ruby
gem 'rails', '~> 5.0.7'
```

```bash
bundle update rails
```

You'll likely also need to bump `cancancan` to `~> 3.0`, `inherited_resources` to `~> 1.8`, `kaminari` to `~> 1.0`, `api-pagination` to `~> 4.8`, `ransack` to `~> 1.8`, `rspec-rails` to `~> 3.7`, `factory_bot_rails` to `~> 4.11`, `database_cleaner` to `~> 1.7`, `bullet` to `~> 5.7`, `devise` to `~> 4.4`, `activeadmin` to `~> 1.4` (already), `shoulda-matchers` to `~> 3.1`. Run `bundle update` and let bundler pick the highest mutually compatible set, then pin.

- [ ] **Step 1.2: Run `app:update`**

```bash
bin/rails app:update
```

Step through every prompt. Accept new files (`bin/update`, `bin/yarn`, `config/initializers/new_framework_defaults.rb`, `config/initializers/application_controller_renderer.rb`, `config/initializers/cors.rb`, `config/initializers/filter_parameter_logging.rb`). Reject overwrites of `config/routes.rb`, `config/database.yml`, and anything you've already customized.

- [ ] **Step 1.3: Fix `before_filter` → `before_action`**

In `app/controllers/api/v1/api_controller.rb`:

```ruby
# Replace:
before_filter :set_default_response_format
before_filter :set_default_response_headers
skip_before_filter :verify_authenticity_token

# With:
before_action :set_default_response_format
before_action :set_default_response_headers
skip_before_action :verify_authenticity_token
```

Search for any other instances:

```bash
grep -rn 'before_filter\|skip_before_filter\|after_filter\|around_filter' app/ lib/
```

- [ ] **Step 1.4: Audit `belongs_to` for Rails 5 required-by-default**

Rails 5 makes `belongs_to` validate presence by default. Models with optional parents must add `optional: true`. From the schema:

- `Day belongs_to :sprint` — schema allows `sprint_id` to be null but the app always sets it. Keep as required (no change).
- `DayTask belongs_to :day, :task, :next, :previous` — `next` and `previous` are linked-list pointers and ARE nullable. Add `optional: true`:

```ruby
belongs_to :next, class_name: 'DayTask', optional: true
belongs_to :previous, class_name: 'DayTask', optional: true
```

- `SprintProject belongs_to :sprint, :project` — required (already validated). No change.
- `SprintProjectTask belongs_to :sprint_project, :task` — required. No change.
- `Sprint belongs_to :user` — required. No change.
- `Project belongs_to :user` — required. No change.
- `Task belongs_to :project` — schema allows null but the codebase doesn't. Add `optional: true` defensively to avoid breaking existing test fixtures, then remove later if FactoryBot always sets project.

Open each model file and apply.

- [ ] **Step 1.5: Add migration version suffixes**

Rails 5 requires `ActiveRecord::Migration[N.M]` on every migration class. Existing migrations were written for Rails 4.x. Edit each file in `db/migrate/` to use `ActiveRecord::Migration[4.2]`:

```ruby
class CreateTasks < ActiveRecord::Migration[4.2]
```

(Apply the same change to every file in `db/migrate/`.) This preserves Rails 4.2 behavior in the migration runner.

- [ ] **Step 1.6: Run tests**

```bash
bundle exec rspec
```

Expected failures and fixes:

- `ActiveSupport::TestCase` API changes — fix per failure.
- `assert_difference` / response code helpers — fix per failure.
- `respond_to :json` may print a deprecation. Add `gem 'responders', '~> 2.4'` to Gemfile and `include ActionController::MimeResponds` if needed.
- `inherit_resources` may need explicit `respond_to :json` removed in favor of `inherit_resources`'s own handling.

- [ ] **Step 1.7: Smoke test the running server**

```bash
bundle exec rails s
curl -i -H 'Content-Type: application/json' -d '{"username":"x","password":"x"}' http://localhost:3000/api/v1/session
```

Expected: 401 with JSON body `{"errors":"Username not found, please try again"}`. (Anything 5xx means initializer or boot-time breakage.)

- [ ] **Step 1.8: Commit and tag**

```bash
git add -A
git commit -m "chore: upgrade to Rails 5.0"
git tag phase-1-complete
```

---

## Phase 2 — Rails 5.0 → 5.1

**Goal:** Land on Rails 5.1.7.

- [ ] **Step 2.1: Bump Rails**

```ruby
gem 'rails', '~> 5.1.7'
```

`bundle update rails`. Bump dependent gems as bundler complains.

- [ ] **Step 2.2: Run `app:update`** — same review pattern as Phase 1.

- [ ] **Step 2.3: Address known 5.1 breakage**

- `params` is now an `ActionController::Parameters`, not a Hash. Anywhere we treat params as a hash and pass to ActiveRecord, call `.to_h` after `.permit`. Already used correctly in `*_controller.rb` files via `permit(...).merge(...)` — no change expected, but grep:

```bash
grep -rn 'params\[.*\]\.to_h\|params\.merge' app/
```

- `Capybara::DSL` no longer auto-included in feature specs (irrelevant — we have no feature specs).

- [ ] **Step 2.4: Run tests, smoke test, commit, tag**

```bash
bundle exec rspec
git commit -am "chore: upgrade to Rails 5.1"
git tag phase-2-complete
```

---

## Phase 3 — Rails 5.1 → 5.2 + Ruby 2.4 → 2.6

**Goal:** Land on Rails 5.2.8.1 / Ruby 2.6.10. Migrate to encrypted credentials.

- [ ] **Step 3.1: Bump Ruby first** (Rails 5.2 is fine on 2.4 but 2.6 is required for Rails 6).

`.ruby-version` → `2.6.10`. Update `Gemfile`'s `ruby` line. Reinstall with rbenv/asdf. `bundle install`. Run tests.

- [ ] **Step 3.2: Bump Rails**

```ruby
gem 'rails', '~> 5.2.8'
```

`bundle update rails`. Bump dependents.

- [ ] **Step 3.3: Run `app:update`**

In particular let it create `config/credentials.yml.enc` and `config/master.key` (the latter is gitignored automatically). The old `config/secrets.yml` (if present) can be deleted afterward.

- [ ] **Step 3.4: Migrate secrets to credentials**

```bash
EDITOR=vim bin/rails credentials:edit
```

Add anything from `config/secrets.yml`. The only secret in this app is `secret_key_base`, which Rails 5.2 generates automatically. On Heroku, set `RAILS_MASTER_KEY` (or keep `SECRET_KEY_BASE` env var — both work).

Delete `config/initializers/secret_token.rb` entirely — Rails 5.2+ handles this through credentials.

- [ ] **Step 3.5: Address known 5.2 breakage**

- `update_attributes` → `update` (we already verified there are no instances).
- `Bootsnap` is now in `boot.rb` by default; let `app:update` add it.
- HTTP_REFERER tightening in CSRF — N/A for our skip_before_action API.

- [ ] **Step 3.6: Tests, smoke, commit, tag**

```bash
bundle exec rspec
git commit -am "chore: upgrade to Rails 5.2 + Ruby 2.6, move to encrypted credentials"
git tag phase-3-complete
```

---

## Phase 4 — Rails 5.2 → 6.0 + Ruby 2.6 → 2.7

**Goal:** Land on Rails 6.0.6.1 / Ruby 2.7.8. This is the biggest phase — Zeitwerk autoloading is the major change.

- [ ] **Step 4.1: Bump Ruby**

`.ruby-version` → `2.7.8`. Reinstall, `bundle install`, run tests. Expect noisy keyword-argument deprecation warnings — they're warnings, not failures, in Ruby 2.7. Suppress with `RUBYOPT='-W:no-deprecated'` in development if they're drowning real output.

- [ ] **Step 4.2: Bump Rails**

```ruby
gem 'rails', '~> 6.0.6'
```

Other bumps: `cancancan ~> 3.3`, `inherited_resources ~> 1.13`, `kaminari ~> 1.2`, `ransack ~> 2.4`, `rspec-rails ~> 4.0`, `factory_bot_rails ~> 6.0`, `database_cleaner-active_record ~> 1.8` (note: `database_cleaner` was split — replace with `database_cleaner-active_record`), `devise ~> 4.7`, `activeadmin ~> 2.9`, `shoulda-matchers ~> 4.0`, `puma ~> 4.3`.

- [ ] **Step 4.3: Run `app:update`**

Accept the new framework defaults file (`new_framework_defaults_6_0.rb`). Review every change.

- [ ] **Step 4.4: Switch to Zeitwerk autoloader**

In `config/application.rb`:

```ruby
config.autoloader = :zeitwerk
```

Run `bin/rails zeitwerk:check`. It will surface naming mismatches between filename and class name. Likely none in this codebase since file/class names match Rails conventions, but if anything trips, rename the file or fix the constant.

- [ ] **Step 4.5: Address `database_cleaner` split**

Replace `gem 'database_cleaner'` with `gem 'database_cleaner-active_record'`. In `spec/support/database_cleaner.rb`, `DatabaseCleaner[:active_record]` syntax (already in use) continues to work — no spec changes needed.

- [ ] **Step 4.6: Webpacker / asset pipeline decision**

Rails 6 makes Webpacker the default for JavaScript. Since this app is a JSON API with one admin UI (ActiveAdmin), we DO NOT need Webpacker. Stay on Sprockets for ActiveAdmin's CSS/JS. When `app:update` asks about installing Webpacker, decline.

- [ ] **Step 4.7: `respond_to :json` / inherited_resources sanity check**

`inherited_resources 1.13` works on Rails 6 but check that all controller specs still pass. The gem moved methods around between 1.7 and 1.13.

- [ ] **Step 4.8: Tests, smoke, commit, tag**

```bash
bundle exec rspec
git commit -am "chore: upgrade to Rails 6.0 + Ruby 2.7, Zeitwerk autoloader"
git tag phase-4-complete
```

---

## Phase 5 — Rails 6.0 → 6.1 + Ruby 2.7 → 3.1

**Goal:** Land on Rails 6.1.7.x / Ruby 3.1.x. Ruby 3.x is the Heroku-22+ minimum.

- [ ] **Step 5.1: Bump Ruby to 3.1.x**

`.ruby-version` → `3.1.4`. `bundle install`. Expect failures from gems that don't support Ruby 3.x. Likely culprits and bumps:

- `psych` (YAML) — Ruby 3.1 ships psych 3.3, mostly fine but `Psych.safe_load` defaults changed.
- `sass-rails`, `coffee-rails` — keep on Sprockets-compatible versions.
- `bcrypt` — bump to `~> 3.1.16`.
- `bullet` — bump to `~> 7.0`.

Address the keyword-argument errors that were warnings in 2.7 — they're hard errors now. Most show up as `ArgumentError: wrong number of arguments` in tests. Fix call sites by adding `**` to splat hashes meant as keyword args.

- [ ] **Step 5.2: Bump Rails**

```ruby
gem 'rails', '~> 6.1.7'
```

`bundle update rails`. Other bumps as bundler indicates.

- [ ] **Step 5.3: Run `app:update`** — accept `new_framework_defaults_6_1.rb`.

- [ ] **Step 5.4: Known 6.1 breakage to scan for**

- `Rails.application.config.active_record.belongs_to_required_by_default` is now in defaults.
- `where.not` semantics changed (NOR → NAND). We have no `where.not` in the app; verify with `grep -rn 'where\.not' app/`.
- `ActiveStorage::Blob#service_name` — N/A (no ActiveStorage).
- Default Active Record encryption — N/A unless we want to use it.

- [ ] **Step 5.5: Tests, smoke, commit, tag**

```bash
bundle exec rspec
git commit -am "chore: upgrade to Rails 6.1 + Ruby 3.1"
git tag phase-5-complete
```

---

## Phase 6 — Rails 6.1 → 7.0

**Goal:** Land on Rails 7.0.8.x.

- [ ] **Step 6.1: Bump Rails**

```ruby
gem 'rails', '~> 7.0.8'
```

Major dependent bumps: `cancancan ~> 3.5`, `inherited_resources ~> 1.14`, `rspec-rails ~> 6.0`, `factory_bot_rails ~> 6.2`, `devise ~> 4.9`, `activeadmin ~> 3.1`, `shoulda-matchers ~> 5.0`, `puma ~> 6.0`, `bootsnap ~> 1.16`, `selenium-webdriver` (newer Capybara).

- [ ] **Step 6.2: Run `app:update`** — accept `new_framework_defaults_7_0.rb`.

- [ ] **Step 6.3: Notable 7.0 changes**

- Sprockets is now optional (`sprockets-rails` gem). ActiveAdmin still needs it — keep it in `Gemfile`.
- `button_to` defaults to `method: :post` (N/A — no views).
- New default `cookies_serializer = :json` (already true since 4.2 defaults).
- ActiveSupport::Duration parts hash format change (N/A).
- New `assert_no_changes` semantics (likely irrelevant).

- [ ] **Step 6.4: Audit `inherited_resources` thoroughly**

`inherited_resources` 1.14 supports Rails 7.0 but the gem is in maintenance mode. If specs fail in unrecoverable ways, the fallback is to inline the standard CRUD actions in the few controllers that use it (`Sprints`, `Days`, `SprintProjects`, `SprintProjectTasks`, `DayTasks`, `Tasks`, `Projects`, `Sessions`, `Users`). That's ~9 small controllers — under a day's work as a fallback. Decide based on whether the green-test bar is met.

- [ ] **Step 6.5: Tests, smoke, commit, tag**

```bash
bundle exec rspec
git commit -am "chore: upgrade to Rails 7.0"
git tag phase-6-complete
```

---

## Phase 7 — Rails 7.0 → 7.1 + Ruby 3.1 → 3.3

**Goal:** Land on Rails 7.1.x / Ruby 3.3.x — the deployment target.

- [ ] **Step 7.1: Bump Ruby to 3.3.x**

`.ruby-version` → `3.3.6` (or whatever the latest patch is on the day). `bundle install`. Address gem incompatibilities:

- `bigdecimal`, `mutex_m`, `drb`, `base64` are bundled gems that left stdlib in 3.4+. On 3.3 they still work; just verify Gemfile.lock contains them (Bundler picks them up automatically when needed).
- `net-imap`, `net-pop`, `net-smtp` similarly — may need explicit gem entries.

- [ ] **Step 7.2: Bump Rails**

```ruby
gem 'rails', '~> 7.1.0'
```

Dependent bumps: `inherited_resources ~> 1.15` or 2.x (verify on rubygems.org), `activeadmin ~> 3.2+`, `puma ~> 6.4`, `selenium-webdriver` newest.

- [ ] **Step 7.3: Run `app:update`** — accept `new_framework_defaults_7_1.rb`.

- [ ] **Step 7.4: Address 7.1 changes**

- `protect_from_forgery` is no longer auto-prepended to ApplicationController — verify the existing call still does what we expect. We use `protect_from_forgery` in `ApplicationController` (HTML/admin) and skip it in `ApiController` — both should still work.
- `bin/setup` updated.
- Default Brotli/Zstd compression for asset pipeline (N/A for API).
- `config.active_record.use_yaml_unsafe_load = false` — already false by default; check no test fixtures rely on YAML-loading objects.

- [ ] **Step 7.5: Tests, smoke, commit, tag**

```bash
bundle exec rspec
git commit -am "chore: upgrade to Rails 7.1 + Ruby 3.3"
git tag phase-7-complete
```

---

## Phase 8 — Heroku stack migration

**Goal:** Deploy the upgraded app to a heroku-22 (or heroku-24) stack.

- [ ] **Step 8.1: Verify Heroku app stack**

```bash
heroku stack -a <app-name>
```

If on heroku-20 (or older), it must be moved.

- [ ] **Step 8.2: Move to staging first**

Create a staging app from a fresh build:

```bash
heroku create queuer-server-staging --stack heroku-22
heroku addons:create heroku-postgresql:essential-0 -a queuer-server-staging
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key) -a queuer-server-staging
git push https://git.heroku.com/queuer-server-staging.git HEAD:main
heroku run rake db:schema:load -a queuer-server-staging
heroku run rake db:seed -a queuer-server-staging
```

Smoke test with `curl` against staging URL.

- [ ] **Step 8.3: Promote to production**

Two options — choose based on risk tolerance:

**a. In-place:** `heroku stack:set heroku-22 -a <prod-app> && git push heroku main`. Production goes down for the deploy window (~1–3 minutes).

**b. Cut over via DNS:** Promote staging to be the new production by renaming, swapping DNS / domain attachments. Zero-downtime but more steps.

For a small app, (a) is fine.

- [ ] **Step 8.4: Verify production**

```bash
heroku logs --tail -a <prod-app>
curl -i https://<prod-host>/api/v1/session  # expect 401 with our error JSON
```

- [ ] **Step 8.5: Final commit and tag**

```bash
git tag rails-7.1-deployed
git push origin --tags
```

---

## Risks and known unknowns

- **`inherited_resources` viability on Rails 7.1.** Maintenance-mode gem. The plan includes a fallback (inline the CRUD), but it's the single biggest upgrade risk. If you hit a wall, do that conversion as a separate PR before attempting Rails 7.0 → 7.1.
- **ActiveAdmin Phase-0 conversion.** We're rewriting an admin UI. The current `app/admin/*.rb` files are SimpleAdmin DSL. Budget half a day for the DSL conversion + admin smoke tests.
- **Test gaps.** The existing suite covers requests well but has thin model coverage (only `day_spec.rb`). Some breakage will only surface on staging. Phase 8.2 (staging deploy) is the catch-all.
- **Heroku Postgres major version.** A long-dormant app may be on a Postgres version Heroku no longer supports for its current plan. Run `heroku pg:info` early; if needed, schedule a `pg:upgrade` separately — don't bundle it with the Rails upgrade.

## Self-review (per skill checklist)

- **Spec coverage:** Every Rails minor + Ruby bump in the upgrade has a dedicated phase. Heroku stack move has its own phase. Dependency replacements are handled in Phase 0 before any Rails bump. Gap: no formal rollback procedure documented per phase — but each phase ends with a tag, so `git reset --hard <previous-tag>` is the rollback.
- **Placeholder scan:** No "TBD" or "implement later". Fallback paths (e.g. inline CRUD if `inherited_resources` breaks) are described concretely.
- **Type/name consistency:** Gem names, file paths, and version pins are spelled the same throughout. The Ruby version progression (2.3 → 2.4 → 2.6 → 2.7 → 3.1 → 3.3) and Rails progression (4.2 → 5.0 → 5.1 → 5.2 → 6.0 → 6.1 → 7.0 → 7.1) match between the introduction and the phase headers.
