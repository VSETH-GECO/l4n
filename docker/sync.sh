#!/bin/bash

set -eo pipefail

while [ 1 -eq 1 ] ; do
  sleep $(( ( $( date -f - +%s- <<<"${DUMP_TIME:-19:30}"$' tomorrow\nnow' ) 0 ) % 86400 ))
  echo "Job starting at $(date)"
  rclone sync --stats-one-line -v /storage ${DUMP_URL} > /tmp/sync.log 2>&1
  eval "TURL=${DUMP_HC_URL}"
  curl -fsS -m 10 --retry 5 --data-binary @/tmp/sync.log "${TURL}"
  echo "Job ended at $(date)"
done
