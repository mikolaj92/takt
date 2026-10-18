#!/bin/sh
set -eu
. "/Users/mini-m4-0/.nas-data/Developer/takt/main-wt-55/tools/lib/mojo_env.sh"
takt_ensure_flock "/Users/mini-m4-0/.nas-data/Developer/takt/main-wt-55/.local-checks/tmp/pytest-of-mini-m4-0/pytest-1/test_takt_ensure_flock_seriali0/vendor/.emberjson.setup.lock" "$0" "$@" || exit $?
echo start >> "/Users/mini-m4-0/.nas-data/Developer/takt/main-wt-55/.local-checks/tmp/pytest-of-mini-m4-0/pytest-1/test_takt_ensure_flock_seriali0/order.log"
sleep 0.15
echo end >> "/Users/mini-m4-0/.nas-data/Developer/takt/main-wt-55/.local-checks/tmp/pytest-of-mini-m4-0/pytest-1/test_takt_ensure_flock_seriali0/order.log"
