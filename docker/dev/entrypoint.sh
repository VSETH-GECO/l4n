#!/bin/bash
set -eo pipefail

bundle check > /dev/null || bundle install
yarn install --check-files

# Puma refuses to start if a pid file from a killed container is left over
rm -f tmp/pids/server.pid

bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare

exec "$@"
