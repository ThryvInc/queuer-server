# Heroku Deploy Runbook — Rails 4.2 → 7.1 cutover

App: **queuer-production** (Heroku, region `us`).
Branch to deploy: `master` at tag `phase-4-prep-complete`.
Pre-upgrade safety tag (rollback target): `pre-upgrade-baseline`.

## TL;DR — recommended path

This is a small, single-dyno app on Basic plan. Do an **in-place deploy with brief downtime** (`heroku maintenance:on` → stack bump → push → migrate → smoke test → maintenance off). Total expected window: ~10 minutes. A staging-app dance is overkill here.

---

## 0. Pre-flight diagnostics (recap from local prep)

These were captured during local prep; re-run if anything has shifted.

```
heroku apps:info -a queuer-production
heroku pg:info -a queuer-production
heroku config -a queuer-production
heroku ps -a queuer-production
```

Snapshot at prep time (2026-04-30):

| Item                  | Value                                 | Action                                                                      |
| --------------------- | ------------------------------------- | --------------------------------------------------------------------------- |
| Stack                 | **heroku-16** (EOL'd, deprecated)     | **MUST upgrade**. Recommend `heroku-24`.                                    |
| Dynos                 | 1 web, Basic                          | Will incur ~10 min downtime on in-place deploy.                              |
| Postgres              | `essential-1`, **PG 17.9**            | Compatible with heroku-22/24 — no `pg:upgrade` needed.                       |
| `RAILS_MASTER_KEY`    | **NOT set** on Heroku (verified)      | Must be set before first deploy (see §2).                                    |
| `SECRET_KEY_BASE`     | Set (legacy long hex)                 | Keep — Rails 7.1 still honors it.                                            |
| Other env             | `RACK_ENV`, `RAILS_ENV=production`, `RAILS_SERVE_STATIC_FILES=enabled`, `LANG`, `DATABASE_URL`, `HEROKU_POSTGRESQL_WHITE_URL` | All fine. |

If any of those have changed since prep, reconcile before continuing.

---

## 1. Local pre-flight (in this repo)

Run from `/Users/ell/development/rails/queuer-server` on `master`.

```
git status
git log --oneline -5
git fetch --tags
git tag --list | grep phase-4-prep-complete
bundle exec rspec
SECRET_KEY_BASE=test_only RAILS_ENV=production bundle exec rails runner "puts Rails.version"
```

Expectations:
- working tree clean
- HEAD tagged `phase-4-prep-complete`
- 35 examples, 0 failures
- prints `7.1.6`

If any check fails, **stop** and fix before touching Heroku.

Confirm the heroku git remote points at the right app:

```
git remote -v
```

Expect a `heroku` remote → `https://git.heroku.com/queuer-production.git`. If missing:

```
heroku git:remote -a queuer-production
```

---

## 2. Set RAILS_MASTER_KEY on Heroku

Your local `config/master.key` was generated during prep. Heroku does **not** have one yet. Set it now (this is the only `heroku config:set` you should run before deploy):

```
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key) -a queuer-production
```

Verify:

```
heroku config:get RAILS_MASTER_KEY -a queuer-production
```

Should match `cat config/master.key`. If you previously set a different `RAILS_MASTER_KEY`, this will overwrite it — but the encrypted credentials file in this repo was generated with the *local* key, so the local key is the one that matches. Either way, the local key wins.

---

## 3. Bump the stack (heroku-16 → heroku-24)

Required because heroku-16 is end-of-life.

```
heroku stack:set heroku-24 -a queuer-production
```

This stages the change; it takes effect on the **next deploy** in step 5. Heroku may print a banner advising a ruby version compatible with heroku-24 — Ruby 3.3.11 is supported on heroku-24, so we're fine.

Sanity-check buildpacks (should be `heroku/ruby`; if empty, add it):

```
heroku buildpacks -a queuer-production
heroku buildpacks:set heroku/ruby -a queuer-production   # only if buildpacks list is empty
```

---

## 4. Maintenance on

```
heroku maintenance:on -a queuer-production
```

Verify the public URL now returns the maintenance page:

```
curl -i https://queuer-production.herokuapp.com/
```

(Expect HTTP 503 with the Heroku maintenance HTML.)

---

## 5. Deploy

The Heroku remote uses the `main` ref convention. Local branch is `master`. Push as a refspec.

```
git push heroku master:main
```

Watch the build output. Things to verify during build:

- Detected: Ruby 3.3.11
- Bundler installs cleanly (no native-extension failures)
- Asset compilation: this app is JSON-only and has no `app/assets`, so `assets:precompile` should be a no-op or skipped. If it errors, that's an unexpected issue — abort and rollback (§8).
- Release phase runs `bundle exec rake db:migrate` (per `Procfile`). Watch for migration output.

---

## 6. Post-release sanity

```
heroku ps -a queuer-production
heroku logs --tail -a queuer-production
```

In another terminal, confirm release migrations succeeded:

```
heroku logs -a queuer-production --source app --dyno release --num 200
```

Look for `Migrations are pending` — there shouldn't be any. Look for `[ActiveRecord]`/`Migrating to ...` lines and a clean exit.

---

## 7. Maintenance off + smoke tests

```
heroku maintenance:off -a queuer-production
```

Run smoke tests against production. Each as a separate command:

```
curl -i https://queuer-production.herokuapp.com/
```
Expect: 404 (no root route — `public/index.html` was removed during prep).

```
curl -i -X POST -H 'Content-Type: application/json' -d '{"username":"x","password":"x"}' https://queuer-production.herokuapp.com/api/v1/session
```
Expect: 401 with body `{"errors":"Username not found, please try again"}`.

```
curl -i -H 'X-Qer-Authorization: bogus-key' https://queuer-production.herokuapp.com/api/v1/sprints
```
Expect: 401 with body `{"errors":"API key is invalid"}`.

If you have a real user's API key in 1Password, do one extra authenticated read (e.g. `GET /api/v1/sprints` with the real `X-Qer-Authorization` header) and verify a 200 with the expected JSON shape.

If all three smoke tests pass: **deploy is good.** Tag it locally:

```
git tag rails-7.1-deployed
git push origin rails-7.1-deployed
```

---

## 8. Rollback procedure

Pick the **least invasive** path that recovers service.

### 8a. Slug rollback (fastest, no code reset)

If the new release boots but misbehaves at runtime:

```
heroku releases -a queuer-production
heroku rollback -a queuer-production           # rolls back one release
heroku rollback v<NN> -a queuer-production     # or pick a specific release
```

Caveats: rollback restores the slug, but **does not undo migrations or stack/config changes**. If your migrations were destructive (this upgrade's were not — only versioning sentinels), you may need a manual DB restore from a Heroku PG backup.

### 8b. Hard reset to pre-upgrade baseline (last resort)

Only if 8a doesn't recover and you must restore the Rails 4.2 codebase.

```
git checkout master
git fetch origin
git reset --hard pre-upgrade-baseline
git push --force heroku master:main
heroku stack:set heroku-22 -a queuer-production    # heroku-16 is gone; 22 is the oldest still buildable for older Ruby
```

**Risks of this path:**
- `git push --force` rewrites the heroku remote — fine for heroku, but note that you should NOT run this against `origin` unless you genuinely intend to discard the upgrade history.
- Older Ruby (2.3.1) won't build on heroku-22 either; you may end up needing heroku-20 stack which is also EOL'd. **Truly rolling back the codebase past a stack-bump is hard** — strongly prefer 8a or fixing forward.
- Restore PG from backup if migrations corrupted data: `heroku pg:backups:restore <backup_id> DATABASE_URL -a queuer-production`.

If you reach the hard-reset point, it's almost always cheaper to fix the new code forward than to push 4.2 back onto modern stacks.

---

## 9. Alternative: zero-downtime via staging app

Not recommended for this app size, but documented for completeness.

```
heroku create queuer-staging --remote staging --stack heroku-24
heroku addons:create heroku-postgresql:essential-1 -a queuer-staging
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key) RAILS_ENV=production SECRET_KEY_BASE=$(bundle exec rails secret) -a queuer-staging
git push staging master:main
heroku run rake db:migrate -a queuer-staging
# smoke test queuer-staging.herokuapp.com URLs
# if happy, point production at the same slug or repeat steps 1-7 against queuer-production
```

This costs a second Basic dyno + Postgres add-on for the duration. ~$0.02/hour while up.

---

## 10. Notes / things that bit us

- **Static placeholder gone:** `public/index.html` was deleted during prep, so `GET /` will now genuinely 404 in production (it returned the OpenShift page before).
- **Credentials:** `config/credentials.yml.enc` is empty content, but the file itself exists so Rails 7.1's encrypted-config bootstrap works. If you ever store real secrets in it, run `EDITOR='code --wait' bin/rails credentials:edit` locally and commit the resulting `credentials.yml.enc` (never the `master.key`).
- **No staging:** there is no staging environment — only production. Test thoroughly locally first.
- **Single web dyno:** during release-phase migrations, the dyno is briefly unavailable; combined with `maintenance:on`, total downtime ~5–10 minutes for this deploy.
