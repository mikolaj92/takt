#!/bin/sh
# Run a Mojo smoke for takt.
# POSIX /bin/sh: same family as setup_ember_json.sh and tools/lib/mojo_env.sh.
# Toolchain discovery is the single source in tools/lib/mojo_env.sh — do not
# re-list pixi candidates here. Direct exec mojo; no nested pixi wrapper.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$root/tools/lib/mojo_env.sh"

target="${1:?mojo file}"
case "$target" in
  /*) file=$target ;;
  *) file=$root/$target ;;
esac

if ! takt_discover_mojo "$root"; then
  echo "mojo not found; install pixi deps, set FALA_PIXI_ENV, or put mojo on PATH" >&2
  exit 1
fi

cd "$root"
"$root/tools/setup_ember_json.sh"
exec mojo run -I mojo -I vendor/EmberJson "$file"
