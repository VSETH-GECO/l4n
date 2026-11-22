#!/bin/bash
set -eo pipefail

bundle check > /dev/null || bundle install
yarn install --check-files

# Puma refuses to start if a pid file from a killed container is left over
rm -f tmp/pids/server.pid

bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare

# With DEV_IDLE set (e.g. in .env), keep the container running without starting
# the app, so it can be started and restarted on demand with
#   docker compose -f docker-compose.dev.yml exec app bin/dev
if [ -n "$DEV_IDLE" ]; then
  echo "DEV_IDLE is set, not starting the app. Start it with: docker compose -f docker-compose.dev.yml exec app bin/dev"
  exec sleep infinity
fi

exec "$@"
