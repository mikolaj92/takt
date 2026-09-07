#!/bin/sh
# Fala-compatible subprocess entry for Takt cascade step (Mojo).
# POSIX /bin/sh: same family as setup_ember_json.sh and tools/lib/mojo_env.sh.
# Toolchain discovery is the single source in tools/lib/mojo_env.sh — do not
# re-list pixi candidates here.
# Expects Fala effector env (FALA_EFFECTOR_*) or TAKT_REQUEST_PATH.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$root/tools/lib/mojo_env.sh"

if ! takt_discover_mojo "$root"; then
  echo '{"ok":false,"error":"mojo not found"}' >&2
  exit 127
fi

cd "$root"
"$root/tools/setup_ember_json.sh"
exec mojo run -I mojo -I vendor/EmberJson mojo/takt/step_main.mojo
