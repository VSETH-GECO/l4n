#!/bin/bash

set -eo pipefail

echo "Preparing database"
rails db:prepare
echo "Writing out crontab"
whenever --update-crontab
echo "Launching supervisord"

exec dumb-init supervisord -n