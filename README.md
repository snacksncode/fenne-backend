# Fenne API

Rails API for household meal planning, recipes, groceries, pantry stock and consumption. The mobile app lives in the sibling `frontend` repository. Domain terminology is in the workspace's `../CONTEXT.md`; API and code conventions are in [AGENTS.md](AGENTS.md).

## Development

Use Ruby 3.4.2, as specified in `.ruby-version`, and Bundler. Dependencies are locked in `Gemfile.lock`; Rails uses SQLite databases under `storage/`.

```sh
bundle install
bundle exec rails db:prepare
bundle exec rails server -p 4000
```

Port 4000 matches the mobile development API address. `bin/setup` is an alternative setup script, but it also clears logs/tempfiles and starts a server unless passed `--skip-server`. Reuse an existing server when one is running.

`GET /up` is the public health endpoint. The application API and ActionCable endpoint are under `/v2`; exact routes are in [config/routes.rb](config/routes.rb).

## API conventions

Authenticated requests use `Authorization: Bearer <session-token>`. JSON request fields are top-level. Responses use a shared envelope:

```json
{"status":"success","data":{}}
```

```json
{"status":"error","errors":{"email":["format invalid"]}}
```

Dry validation contracts live close to their controllers. Family-owned data must stay scoped to the current Family. Related writes that form one user action must be atomic; use the existing forms and services for their domain rules.

## Checks

```sh
bundle exec rails test
bundle exec rails zeitwerk:check
bundle exec rubocop --cache false
bundle exec brakeman --no-pager
```

Run a focused test by appending its path to `rails test`. `PARALLEL_WORKERS=1 bundle exec rails test` uses one worker when parallel worker IPC is unavailable. Tests use the separate test database configured in `config/database.yml`.

## Where behavior lives

- `app/controllers/v2/`: request contracts, authorization and response handling.
- `app/form/`, `app/services/`: domain writes, quantity conversion, purchasing and grocery generation.
- `app/models/`: persistence, associations and model invariants.
- `app/serializers/`: response data; `app/controllers/concerns/`: shared rendering/invalidation helpers.
- `app/channels/`: authenticated Family invalidation streams.
- `app/jobs/`, `config/recurring.yml`: background work; production auto-consumption runs hourly.

Development and production ActionCable use Solid Cable. Production also configures Solid Queue and Solid Cache databases. Database names and migration paths are in `config/database.yml`; queue workers and recurring schedules are configured under `config/`. Preserve `storage/` databases and Rails credentials when working locally.
