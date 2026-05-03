# Rails 4.2 → 7.1 + Ruby 2.3 → 3.3 Upgrade Plan (big-bang)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the queuer-server Rails JSON API from Rails 4.2.7.1 / Ruby 2.3.1 to Rails 7.1 / Ruby 3.3.x in a single jump, deploy to a heroku-22 (or heroku-24) stack.

**Architecture:** Big-bang upgrade. Edit `Gemfile` and `.ruby-version` to target Rails 7.1 + Ruby 3.3 in one shot, fix `bundle install` issues, run `bin/rails app:update`, then run the test suite and fix breakage iteratively. Admin UI (`app/admin/*` + `simple_admin`) is **deleted**, not ported — git history preserves it if it ever needs to come back. Dev/test DB stays on SQLite for minimal env setup; production stays on Postgres.

**Tech Stack:** Rails 7.1, Ruby 3.3, Postgres (prod), SQLite (dev/test), Puma, RSpec, FactoryBot, CanCanCan, Heroku-22 / Heroku-24 stack.

---

## Ground rules

1. **No incremental Rails minors.** Jump straight from 4.2 → 7.1. The user has explicitly opted into the big-bang approach for this app.
2. **No worktree, no dual-boot.** Work directly on `master`.
3. **Tests are the safety net.** Existing `spec/` suite is what tells us the upgrade succeeded. We may discover the suite has pre-existing red even on the current code; that's fine to flag and proceed.
4. **Iterative breakage fixing.** After bumping versions, expect a flurry of test failures. Fix them by category (one fix → re-run → next category) rather than trying to anticipate every deprecation up front.
5. **Each phase ends with a tag.** `phase-1-complete`, `phase-2-complete`, etc. Rollback is `git reset --hard <tag>`.
6. **The user's global CLAUDE.md applies.** No compound shell commands (`&&`, `|`, `;`, `$(...)`, etc.). Use `/tmp/queuer-server/<name>.sh` scripts for multi-step operations. Tests written/modified follow the three-step verify-by-mutation process from `~/.claude/CLAUDE.md`.

---

## Phase 1 — Get `bundle install` to succeed on Ruby 3.3 + Rails 7.1

**Goal:** Land the Gemfile + `.ruby-version` on the target versions, install Ruby 3.3.x, and get `bundle install` to complete without errors. Delete the admin UI as part of this since `simple_admin` is the single biggest blocker.

**Files:**
- Modify: `.ruby-version`, `Gemfile`, `Gemfile.lock`, `config/routes.rb`
- Delete: `app/admin/projects.rb`, `app/admin/tasks.rb`, `app/admin/users.rb`, `lib/openshift_secret_generator.rb`

- [ ] **Step 1.1: Tag baseline**

```
git tag pre-upgrade-baseline
```

- [ ] **Step 1.2: Install Ruby 3.3.x via rbenv**

Update `.ruby-version` to `3.3.6` (or the current latest 3.3 patch from `rbenv install -L`). On modern macOS, rbenv typically just works for 3.x — no special OpenSSL flags needed (unlike old Ruby).

```
rbenv install 3.3.6
rbenv rehash
gem install bundler
```

- [ ] **Step 1.3: Delete admin UI**

```
git rm app/admin/projects.rb app/admin/tasks.rb app/admin/users.rb
```

In `config/routes.rb`, remove:

```ruby
mount SimpleAdmin::Engine => '/admin', :as => :simple_admin
```

Delete `lib/openshift_secret_generator.rb` — this was OpenShift-specific; on Heroku we use `SECRET_KEY_BASE` env var directly:

```
git rm lib/openshift_secret_generator.rb
```

- [ ] **Step 1.4: Rewrite Gemfile for Rails 7.1**

Replace the entire `Gemfile` with the target version. Use this as the starting point:

```ruby
source 'https://rubygems.org'

ruby '3.3.6'

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
```

Removed deliberately: `simple_admin`, `formtastic`, `cancan`, `factory_girl_rails`, `capybara-webkit`, `formulaic`, `email_spec`, `awesome_print`, `bullet`, `launchy`, `rails_12factor`, `unicorn`, `coffee-rails`, `sass-rails`, `jquery-rails`, `uglifier`, `simplecov`. The asset-pipeline gems are gone with the admin UI; the test-only conveniences can come back later if needed.

- [ ] **Step 1.5: `bundle install` and fix until green**

```
bundle install
```

Likely failures and fixes:
- **Bundler version mismatch** — Rails 7.1 wants Bundler 2.x. If the system bundler is too old, `gem install bundler` then retry.
- **Native extension build errors** — `pg` needs Postgres dev headers (`brew install libpq` and possibly `bundle config build.pg --with-pg-config=$(brew --prefix libpq)/bin/pg_config`). If you hit this, write the config command to `/tmp/queuer-server/config-pg.sh` and run it.
- **Resolver conflicts** — let bundler suggest version bumps; pin only when needed.

- [ ] **Step 1.6: Commit and tag**

Match repo style (short lowercase, no prefix). Suggested message:

```
git commit -am "bundle on rails 7.1 + ruby 3.3, drop admin"
git tag phase-1-complete
```

---

## Phase 2 — Make the app boot

**Goal:** Get `bundle exec rails s` to start without errors, with the app boot path clean. This means running `app:update`, fixing initializers, adding Procfile/Puma config, fixing migration versions, and addressing autoloader (Zeitwerk) issues.

**Files:**
- Modify: `config/application.rb`, `config/environments/*.rb`
- Modify: `config/initializers/secret_token.rb`, `config/initializers/session_store.rb`, `config/initializers/wrap_parameters.rb`
- Modify: `db/migrate/*.rb` (add migration version suffixes)
- Create: `Procfile`, `config/puma.rb`, `config/credentials.yml.enc`, `config/master.key` (last one .gitignored)
- Generated: `config/initializers/new_framework_defaults_7_1.rb`, `bin/setup`, etc.

- [ ] **Step 2.1: Run `app:update`**

```
bin/rails app:update
```

Step through every prompt. Accept new files (`bin/setup`, `bin/dev`, `config/initializers/cors.rb`, `config/initializers/filter_parameter_logging.rb`, `config/initializers/inflections.rb`, `config/initializers/new_framework_defaults_7_1.rb`, `config/initializers/permissions_policy.rb`, `config/credentials.yml.enc`, `config/master.key`). For overwrites of existing files, **review every diff** before accepting:
- `config/application.rb` — keep customizations (eager_load, log_level, encoding); accept new framework loads.
- `config/database.yml` — keep custom; the existing layout is fine.
- `config/routes.rb` — do NOT overwrite; we already cleaned it up.
- `config/environments/*.rb` — accept the new Rails 7.1 defaults; copy any custom config overrides back in.
- `config/boot.rb` — accept (adds bootsnap).
- `Gemfile` — do NOT overwrite; we already wrote the target Gemfile.

- [ ] **Step 2.2: Replace OpenShift-era initializers**

Replace `config/initializers/secret_token.rb` with the simple ENV-backed form (or delete it entirely — Rails 7.1 reads `secret_key_base` from credentials):

```ruby
# delete the file; Rails 7.1 handles secret_key_base via credentials.yml.enc + RAILS_MASTER_KEY
```

Replace `config/initializers/session_store.rb` with:

```ruby
RailsApp::Application.config.session_store :cookie_store, key: '_railsapp_session'
```

(`config/initializers/wrap_parameters.rb` should already be Rails-conventional — leave it unless `app:update` changed it.)

- [ ] **Step 2.3: Add migration version suffixes**

Rails 5+ requires `ActiveRecord::Migration[N.M]` on every migration class. Edit each file in `db/migrate/` to use `ActiveRecord::Migration[4.2]`. Example:

```ruby
class CreateTasks < ActiveRecord::Migration[4.2]
  ...
end
```

Apply to every file in `db/migrate/`.

- [ ] **Step 2.4: Add Procfile and Puma config**

Create `Procfile`:

```
web: bundle exec puma -C config/puma.rb
release: bundle exec rake db:migrate
```

Create `config/puma.rb` (Rails 7.1's `app:update` may have created this — if so, keep it; otherwise use a stock Heroku-style config):

```ruby
workers ENV.fetch('WEB_CONCURRENCY') { 2 }
threads_count = ENV.fetch('RAILS_MAX_THREADS') { 5 }
threads threads_count, threads_count

preload_app!

port        ENV.fetch('PORT') { 3000 }
environment ENV.fetch('RAILS_ENV') { 'development' }

plugin :tmp_restart
```

- [ ] **Step 2.5: Boot the app**

```
bundle exec rails s
```

Expected first-pass failures and fixes:
- **Zeitwerk autoload errors** — file/class name mismatch. Run `bin/rails zeitwerk:check` for a clean list. Most likely fine for this codebase since names match Rails conventions.
- **`RailsApp::Application` constant references** — verify `config/application.rb` still defines `module RailsApp; class Application < Rails::Application`.
- **`config.eager_load` warnings** — Rails 7.1 may have stronger rules for development vs production.
- **`config.assets.enabled = true` removed** — Sprockets is now optional. With the admin UI gone, we don't need Sprockets at all. If `app:update` left a `sprockets-rails` reference, decide whether to drop it.

Smoke test with curl:

```
curl -i http://localhost:3000/api/v1/session
```

Expected: 4xx (auth or routing) — anything 5xx means boot/initializer breakage.

- [ ] **Step 2.6: Commit and tag**

```
git commit -am "boot on rails 7.1 (app:update, initializers, migrations versioned)"
git tag phase-2-complete
```

---

## Phase 3 — Make tests pass

**Goal:** Run `bundle exec rspec` and fix breakage by category until everything is green. This is the bulk of the upgrade work.

**Files:** Most spec files and many `app/` files will be touched.

- [ ] **Step 3.1: Set up test DB**

```
bundle exec rails db:create
bundle exec rails db:schema:load
RAILS_ENV=test bundle exec rails db:create
RAILS_ENV=test bundle exec rails db:schema:load
```

(Dev/test stays on SQLite per the simplified plan — no Postgres-dev required locally.)

- [ ] **Step 3.2: Run the suite, observe**

```
bundle exec rspec
```

Don't fix anything yet — read the full output and categorize the failures. Group them by category in a scratch file (`/tmp/queuer-server/test-failures.md`).

- [ ] **Step 3.3: Fix by category, in this expected order**

For each category, make the minimal change, re-run rspec, move to the next.

**Category A — `before_filter`/`skip_before_filter` → `before_action`/`skip_before_action`**

Removed in Rails 5.1. Located at `app/controllers/api/v1/api_controller.rb:4-9`:

```ruby
before_action :set_default_response_format
before_action :set_default_response_headers
skip_before_action :verify_authenticity_token
```

Verify with grep that no other instances remain.

**Category B — `belongs_to` required-by-default**

Rails 5+ requires `belongs_to` to validate presence. Add `optional: true` to truly nullable parents:

- `app/models/day_task.rb`: `belongs_to :next, class_name: 'DayTask', optional: true` and same for `:previous` (linked-list pointers, nullable by design).
- `app/models/task.rb`: `belongs_to :project, optional: true` (defensive; tighten once factories audit clean).

Don't blindly add `optional: true` to every belongs_to — only the ones that legitimately allow null.

**Category C — `FactoryGirl` → `FactoryBot` rename**

```
grep -rl FactoryGirl spec/
```

In each file, replace `FactoryGirl` with `FactoryBot`.

**Category D — Capybara driver**

In `spec/rails_helper.rb`, replace `Capybara.javascript_driver = :webkit` with `Capybara.javascript_driver = :selenium_chrome_headless`.

**Category E — `database_cleaner` API**

The gem was split. We're using `database_cleaner-active_record`. The API in `spec/support/database_cleaner.rb` (`DatabaseCleaner[:active_record]…`) is compatible — likely no change needed. If it breaks, revert to the simpler `DatabaseCleaner.strategy = :transaction` pattern.

**Category F — `inherited_resources`**

Highest-risk category. The gem is in maintenance mode and Rails 7.1 compatibility may be partial. If specs for `Sprints`, `Days`, `SprintProjects`, `SprintProjectTasks`, `DayTasks`, `Tasks`, `Projects` controllers all explode in the same way (e.g. missing `respond_to`, `resource` not defined, etc.), the fallback is to **inline standard CRUD actions** in the affected controllers. That's ~9 small controllers — under a day's work. Decide based on whether the breakage looks fixable or requires gem-internal patches.

**Category G — `respond_to :json` / responders**

In Rails 4.2+ `respond_with` lives in the `responders` gem. `inherited_resources` depends on it; bundler should pull it in. If you see `NoMethodError: respond_to`, add `gem 'responders'` to Gemfile.

**Category H — Strong parameters as `ActionController::Parameters`**

We already use `permit(...).merge(...)` correctly. If anything passes raw params to a model, fix to call `.to_h` after `.permit`. Grep:

```
grep -rn 'params\.merge\|params\[.*\]\.to_h' app/
```

**Category I — `paginate` / `api-pagination` / `kaminari`**

Newer `api-pagination` versions changed the helper signature. If the current `paginate` calls in controllers (`sprints_controller.rb`, others) break, consult the api-pagination 5.x docs and adjust.

**Category J — Time / date / serialization quirks**

Rails 7 changed default `time_zone_aware_attributes`, removed `Date#to_time` quirks, and changed how timestamps serialize in JSON. `Day#date` is a `datetime` column — if specs assert exact JSON time formatting, they may need updates. Don't change the model; update the specs to use looser assertions where appropriate.

After each category, run `bundle exec rspec` to track progress.

- [ ] **Step 3.4: Three-step verify any test you change**

If you modify a spec file (not just running it, but editing test code), follow `~/.claude/CLAUDE.md` test verification: (a) tests pass, (b) mutate production code so the affected tests fail, (c) revert mutations and confirm pass. Do this once per modified spec batch — not after every individual edit.

- [ ] **Step 3.5: Final green check**

```
bundle exec rspec
```

Expected: all green. Pending/skipped specs are OK if they were already pending; document any new ones.

- [ ] **Step 3.6: Commit and tag**

```
git commit -am "rails 7.1 test suite green"
git tag phase-3-complete
```

---

## Phase 4 — Smoke test + Heroku deploy

**Goal:** Verify the app works end-to-end locally, then deploy to a heroku-22 (or heroku-24) staging app, smoke test, and promote to production.

- [ ] **Step 4.1: Local smoke test**

```
bundle exec rails s
```

Hit the live endpoints with curl:

```
curl -i -H 'Content-Type: application/json' -d '{"username":"x","password":"x"}' http://localhost:3000/api/v1/session
```

Expected: 401 with `{"errors":"Username not found, please try again"}`. Then create a real user via `rails console` and test an authenticated request:

```
curl -i -H 'X-Qer-Authorization: <api_key>' http://localhost:3000/api/v1/sprints
```

Expected: 200 with `[]`.

- [ ] **Step 4.2: Heroku staging**

Verify current production stack:

```
heroku stack -a <prod-app>
```

If it's heroku-20 (deprecated April 2025), you must move. Create a staging app on heroku-22:

```
heroku create queuer-server-staging --stack heroku-22
heroku addons:create heroku-postgresql:essential-0 -a queuer-server-staging
heroku config:set RAILS_MASTER_KEY=<contents-of-config/master.key> -a queuer-server-staging
git push https://git.heroku.com/queuer-server-staging.git master:main
heroku run rake db:schema:load -a queuer-server-staging
```

(If you want to copy production data: `heroku pg:copy <prod-app>::DATABASE_URL DATABASE_URL -a queuer-server-staging` after a backup.)

- [ ] **Step 4.3: Smoke staging**

```
curl -i https://queuer-server-staging.herokuapp.com/api/v1/session
```

Verify boot, response, and `heroku logs --tail -a queuer-server-staging` for any 5xx.

- [ ] **Step 4.4: Promote to production**

For a small app, in-place is fine:

```
heroku stack:set heroku-22 -a <prod-app>
git push <prod-remote> master:main
heroku run rake db:migrate -a <prod-app>
```

Production is down for the deploy window (~1–3 minutes). Afterward, watch `heroku logs --tail` and verify `curl -i https://<prod-host>/api/v1/session` returns the expected 4xx.

- [ ] **Step 4.5: Final tag**

```
git tag rails-7.1-deployed
git push origin master --tags
```

---

## Risks and known unknowns

- **`inherited_resources` on Rails 7.1.** Maintenance-mode gem; biggest single technical risk. Fallback is inlining ~9 controllers' CRUD (Phase 3 Category F).
- **Boot-time initializer breakage.** OpenShift-era files have global side effects; deleting them carefully is critical. If something boot-fails in production but not dev, suspect missing `RAILS_MASTER_KEY` env var on Heroku.
- **Test suite gaps.** Coverage is heavy on requests, thin on models. Some breakage will only surface on staging — Phase 4.2 is the catch-all.
- **Heroku Postgres major version.** A long-dormant app may be on a Postgres version Heroku no longer supports. Run `heroku pg:info` early; if it requires `pg:upgrade`, do that **separately** from this work.

## Self-review

- **Spec coverage:** All four phases together cover Gemfile/Ruby (P1), boot (P2), tests (P3), deploy (P4). Admin deletion is in P1.
- **Placeholders:** None. Fallback paths described concretely.
- **Type/name consistency:** Ruby version (3.3.6) and Rails version (7.1) repeat consistently throughout. Tag names follow `phase-N-complete` pattern.
