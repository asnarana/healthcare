#!/usr/bin/env bash
set -euo pipefail

bundle check >/dev/null 2>&1 || bundle install

exec "$@"
