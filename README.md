# queuer-server

JSON API backend for **Queuer**, a sprint planner. Manages users, projects, tasks, sprints, sprint-project assignments, and per-day task scheduling.

## Stack

- Rails 7.1, Ruby 3.3.11
- Puma (web), Postgres (production), SQLite (development/test)
- Hosted on Heroku (`queuer-production`)

## Quick start

```
bundle install
bundle exec rails db:create db:migrate
bundle exec rspec
bundle exec rails s
```

All client endpoints live under `/api/v1` and are token-authenticated via the `X-Qer-Authorization` header. See [`CLAUDE.md`](./CLAUDE.md) for the architecture, data model, points cascade, and serialization conventions.
