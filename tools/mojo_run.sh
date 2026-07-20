#!/usr/bin/env bash
# Run a Mojo smoke for takt. Prefers local pixi; falls back to Fala/Splot pixi env.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?mojo file}"
case "$target" in
  /*) file="$target" ;;
  *) file="$root/$target" ;;
esac

if command -v pixi >/dev/null 2>&1 && [[ -f "$root/pixi.toml" ]]; then
  cd "$root"
  if pixi run -- true 2>/dev/null; then
    exec pixi run -- bash -c "mojo run -I mojo \"$file\""
  fi
fi

# Fallback: sibling Fala or Splot pixi env (dev machine layout)
for candidate in \
  "${FALA_PIXI_ENV:-}" \
  "$root/../Fala/.pixi/envs/default/bin" \
  "$root/../Splot/.pixi/envs/default/bin" \
  "$root/.pixi/envs/default/bin"
do
  if [[ -n "$candidate" && -x "$candidate/mojo" ]]; then
    export PATH="$candidate:${PATH:-/usr/bin:/bin}"
    if [[ -z "${CONDA_PREFIX:-}" ]]; then
      export CONDA_PREFIX="$(cd "$candidate/.." && pwd)"
    fi
    if [[ -z "${MODULAR_HOME:-}" ]]; then
      export MODULAR_HOME="${CONDA_PREFIX}/share/max"
    fi
    cd "$root"
    exec mojo run -I mojo "$file"
  fi
done

echo "mojo not found; install pixi deps or set FALA_PIXI_ENV" >&2
exit 1
