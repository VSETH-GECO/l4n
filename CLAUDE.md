# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

L4N is a Rails 7.2 CMS for running LAN parties: ticketing with a QR check-in scanner, a shop, seatmaps, timetables, tournaments, news, events, pages, achievements, a JSON API, and an OAuth2/OIDC provider. It runs only on PostgreSQL (no SQLite or MySQL). The Ruby version is pinned in `.ruby-version` (currently 3.4.13) and Node is `>=26`.

## Commands

```bash
bundle install && yarn                  # install dependencies
bin/dev                                 # dev server (Procfile.dev): rails s over ssl://0.0.0.0:3000 + sass + esbuild watchers
bundle exec rake db:create db:migrate   # DB setup (config/database.yml: user `rails`, dbs `l4n` / `l4n_test`)
bundle exec rake setup:user             # create the first user, with permission to edit users

# Tests (Minitest + SimpleCov)
bundle exec rake test
bundle exec rails test test/unit/operations/user/create_test.rb
bundle exec rails test test/unit/operations/user/create_test.rb -n test_basic

# Lint (all three run in CI along with the tests; see .github/workflows/ci.yml)
bundle exec rubocop
bundle exec haml-lint app/views
yarn run eslint app/javascript

# Translations: extract gettext strings, update locale/*.po and regenerate public/locale/*.json
bundle exec rake translate:run
```

You can also develop in Docker without a local Ruby or Postgres. `docker compose -f docker-compose.dev.yml up --build` uses `docker/dev/` and bind-mounts the repo; on startup it runs bundle and yarn installs and `db:prepare` for dev and test, then `bin/dev`. Run commands inside it with `docker compose -f docker-compose.dev.yml exec app <cmd>`. If you set `DEV_IDLE=1` in `.env`, the app container does the setup but then idles instead of running `bin/dev`. You then start (and restart) the app on demand with `docker compose -f docker-compose.dev.yml exec app bin/dev`, without restarting the containers. (`docker-compose.yml` and `/Dockerfile` are for production only.)

Local development needs a `.env` file. Nothing loads it automatically: Figaro reads ENV, and the dev compose file passes `.env` in through `env_file`. See the README for the minimum set of variables and `DEVELOPMENT.md` for the full list.

## Architecture

### Controllers → Operations (rails_ops)
Controllers stay thin and delegate business logic to **rails_ops** operations in `app/operations`. Typical controller code:
- `op Operations::Admin::NewsPost::Update` builds the operation, for example to render a form. `model` then exposes its model.
- `if run Operations::...::Create` runs it and returns false if validation fails. `run!` raises instead.

Operations subclass `RailsOps::Operation` or `RailsOps::Operation::Model::{Load,Create,Update,Destroy}`. They declare params with a `schema do ... end` block (schemacop) and set the model class with `model ::Foo`. Authorization runs through the operation context's CanCanCan `Ability`.

### Custom autoload namespaces
`config/initializers/namespacing.rb` maps these folders to top-level modules:
- `app/operations` → `Operations::`
- `app/queries` → `Queries::`
- `app/grids` → `Grids::`
- `app/services` → `Services::`

So `app/operations/admin/news_post/create.rb` defines `Operations::Admin::NewsPost::Create`. Queries are `Inquery::Query` subclasses that you invoke with `.call(...)`. Grids are `datagrid` tables used in the admin panel.

### Authorization
- `app/models/ability.rb` holds all CanCanCan rules. Public read access uses the `:read_public` action. Admin rights come from `UserPermission` records (`AVAILABLE_PERMISSIONS`, `SENSITIVE_PERMISSIONS`) and per-tournament `UserTournamentPermission`. The ticket scanner has its own `ScannerUser` Devise model and its own `ScannerAbility`.
- Outside development, `CanCan::AccessDenied` is turned into a 404 (`ApplicationController`).
- Every controller under `Admin::` inherits from `Admin::AdminController`, which uses the `admin` layout and requires `authorize! :access, :admin_panel`.

### Feature flags and settings
- `FeatureFlag` (cached, keys in `FeatureFlag::AVAILABLE_FLAGS`) can switch off whole modules: shop, lan_party, tournaments, events, and others. Many `Ability` rules depend on these flags, so a disabled feature means no permissions for it.
- `AppConfig` (rails-settings-cached) stores runtime settings that admins edit in the admin panel.

### Frontend
- The views are HAML with `simple_form` (Bootstrap 5). Custom inputs live in `lib/simple_form_extensions`.
- Interactivity uses Hotwire (Turbo + Stimulus controllers in `app/javascript/controllers`).
- There are two separate bundles, each with its own JS entry point and stylesheet: the public app (`application.js` / `application.sass.scss`) and the admin panel (`admin.js` / `admin.sass.scss`). esbuild and sass compile them into `app/assets/builds`.
- Remote form modal: link with `data: { turbo_frame: "remote_modal" }`. The controller calls `show_turbo_modal(...)` to show the modal and `update_turbo_modal(...)` when validation fails. The form partial holds only the modal content. `DEVELOPMENT.md` has an example.

### i18n
- All UI strings go through gettext (`_('...')`) using `gettext_i18n_rails` / FastGettext. Keys are namespaced with `|`, as in `_('Admin|%{model_name}|Successfully created') % { model_name: _('NewsPost') }`.
- Translated model attributes use Mobility.
- JS translations come from `public/locale/*.json`, which `bin/po2json` generates.

### Payment gateways
Each gateway is a local Rails engine gem in `payment_gateways/` (dummy, paypal, payrexx; seki is deprecated), referenced via `path:` in the Gemfile. Each engine registers itself in an initializer with `app.config.payment_gateways << ::XyzPayment` and provides `name`, `payment_button_text` and `payment_path`. `dummy_payment` is loaded only in development.

### Tournaments
The `tournament-system` gem handles bracket and swiss logic. `Tournament::*` models (teams, phases, matches) are in `app/models/tournament/`, and the driver adapters are in `app/models/tournament_drivers/`.

## Conventions

- Models follow the section layout in `_model_comment_template.txt` (`# == Attributes ==`, `# == Associations ==`, and so on).
- Tests in `test/unit/` subclass `ApplicationTest` (`test/test_helper.rb`). Before each test, every feature flag is reinitialized and turned on. Use `as_user(user) { run_op!(...) / build_op(...) }` to run operations with that user's `Ability`, and `TestDataFactory` (`test/test_data_factory.rb`) helpers to create records. Calling `Operations::Foo.run!(...)` directly runs without a user context.
- Production enforces SSL (HSTS, secure cookies). Docker deployment (`docker-compose.yml`) runs `db:prepare`, `whenever --update-crontab` and cron at container start.
