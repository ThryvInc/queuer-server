# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

- Rails 4.2 JSON API, Ruby 2.3.1 (`.ruby-version`).
- SQLite in development/test, Postgres in production (`config/database.yml`).
- Originally an OpenShift Rails quickstart; the OpenShift-specific README content is no longer the primary purpose — this is now a JSON API for a sprint/task ("Queuer") application.

## Common commands

- Install: `bundle install`
- DB setup: `bundle exec rake db:create db:migrate` (test DB auto-maintained via `ActiveRecord::Migration.maintain_test_schema!`).
- Run server: `bundle exec rails s` (Unicorn is the configured app server in production).
- Console: `bundle exec rails c`
- Run all specs: `bundle exec rspec`
- Single spec file: `bundle exec rspec spec/requests/api/v1/sprints_spec.rb`
- Single example: `bundle exec rspec spec/requests/api/v1/sprints_spec.rb:12`

There is no separate lint step configured.

## Architecture

### API surface

All client-facing endpoints live under `/api/v1` (`config/routes.rb`) and are JSON-only. Routes are deeply nested:

```
sprints → sprint_projects → sprint_project_tasks
sprints → days           → day_tasks
projects → tasks
sprint_projects → sprint_project_tasks   (also exposed at top level)
```

The SimpleAdmin admin UI (formerly mounted at `/admin`) was dropped during the Rails 7.1 upgrade; this is now a JSON API only.

### Authentication and authorization

- API auth is token-based: `Api::V1::ApiController#current_user` looks up `User` by `api_key` from the `X-Qer-Authorization` header (or `_key` param / `api_key` cookie). CSRF is skipped for the API. Login via `POST /api/v1/session` returns the user including `api_key`. (The legacy `has_secure_password` + session admin/web auth flow was removed with the SimpleAdmin UI.)
- Authorization uses **CanCan** (`app/models/ability.rb`). Permissions are scoped by ownership chains (e.g. `DayTask` is allowed when `day.sprint.user_id == current_user.id`). Most controllers use `load_and_authorize_resource` (often `through: :current_user`).
- `Api::V1::ApiController` defines `ApiKeyNotFound` / `ApiKeyInvalid` as `CanCan::AccessDenied` subclasses so missing/invalid keys produce 401s through the same rescue path.

### Data model and points cascade

The domain models a sprint planner where work is organized two ways simultaneously:

- `User` → `Project` → `Task` (the project's task backlog)
- `User` → `Sprint` → `SprintProject` → `SprintProjectTask` → `Task` (which projects/tasks are committed to a sprint)
- `Sprint` → `Day` → `DayTask` → `Task` (which tasks are scheduled on which day)

So the same `Task` can be referenced from a `Project`, one `SprintProjectTask`, and one or more `DayTask`s. The `DayTask` has `next_id`/`previous_id` columns intended for an ordered linked list of tasks within a day.

**Points are denormalized and cached on parent rows** (`points`, `remaining_points`, `finished_points`). Whenever a `Task` is saved, `Task#after_save` cascades:

- `update_project_points` — recomputes `project.points`/`remaining_points`
- `update_sprint_project_points` — calls `update_points` on every `SprintProject` joined through `sprint_project_tasks`
- `update_day_points` — calls `update_points` on every `Day` joined through `day_tasks`

`DayTask` and `SprintProjectTask` also fire `update_points` `after_create`/`after_destroy`. When changing how tasks/points work, expect to touch all of these callbacks together — the cached counters will silently drift if you skip one.

### JSON serialization

There is no AMS / Jbuilder. Each model overrides `as_json` to control include/except trees and to inject computed fields (e.g. `points`, `remaining_points`, `errors`). Controllers typically just call `render json: object.as_json`. When changing response shape, edit the model's `as_json`, not the controller. `Sprint#as_json` and `Day#as_json` define non-trivial nested-include defaults — match their structure if you add a new association.

### Controllers

- Inherit from `Api::V1::ApiController` and use the `inherited_resources` gem; most CRUD actions are not written explicitly. Override only what you need (commonly `index`, `create`, and `*_params`).
- `paginate` (from `api-pagination` + `kaminari`) is used in custom `index` actions.

### Tests

- RSpec with `factory_girl_rails`, `shoulda-matchers`, `database_cleaner` (transaction strategy by default, deletion for `js: true`), `bullet` for N+1 detection, and `json_spec` helpers.
- Most coverage is in `spec/requests/api/v1/*_spec.rb`. `spec/support/helpers/requests.rb` provides `authorization_headers(user)` — use it for authenticated API requests rather than setting headers manually.
- `spec/support/helpers/requests.rb` references a `REDIS` constant in `activities`/`notifications` helpers, but no Redis is configured in the Gemfile — those helpers appear unused/dead.

## Gotchas

- Ruby 2.3.1 and Rails 4.2 — many modern idioms (`before_action`, keyword args in controller tests, etc.) don't apply. The codebase still uses `before_filter`.
- The repo contains a stray file literally named `{method:core.playback.pause,id:1,jsonrpc:2.0}` at the root and a `.DS_Store` — leave them alone unless explicitly asked to clean up.
- `Api::V1::ApiController#load_index_from_nested_resource` is buggy as written (calls `res.send` on `nil`); don't use it as a reference.
