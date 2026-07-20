#!/usr/bin/env bash
# Run a Mojo smoke for takt. Prefers local pixi; falls back to Fala/Splot pixi
# env or any mojo already on PATH.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?mojo file}"
case "$target" in
  /*) file="$target" ;;
  *) file="$root/$target" ;;
esac

setup_mojo_env() {
  local candidate="$1"
  if [[ -n "$candidate" && -x "$candidate/mojo" ]]; then
    export PATH="$candidate:${PATH:-/usr/bin:/bin}"
    if [[ -z "${CONDA_PREFIX:-}" ]]; then
      export CONDA_PREFIX="$(cd "$candidate/.." && pwd)"
    fi
    if [[ -z "${MODULAR_HOME:-}" ]]; then
      export MODULAR_HOME="${CONDA_PREFIX}/share/max"
    fi
    return 0
  fi
  return 1
}

run_with_mojo() {
  cd "$root"
  exec mojo run -I mojo "$file"
}

if command -v pixi >/dev/null 2>&1 && [[ -f "$root/pixi.toml" ]]; then
  cd "$root"
  if pixi run -- true 2>/dev/null; then
    exec pixi run -- bash -c "mojo run -I mojo \"$file\""
  fi
fi

for candidate in \
  "${FALA_PIXI_ENV:-}" \
  "$root/.pixi/envs/default/bin" \
  "$root/../Fala/.pixi/envs/default/bin" \
  "$root/../Splot/.pixi/envs/default/bin"
do
  if setup_mojo_env "$candidate"; then
    run_with_mojo
  fi
done

# Last resort: mojo already on PATH (CI, mise, manual install)
if command -v mojo >/dev/null 2>&1; then
  # Ensure MODULAR_HOME when missing but CONDA_PREFIX is set
  if [[ -z "${MODULAR_HOME:-}" && -n "${CONDA_PREFIX:-}" ]]; then
    export MODULAR_HOME="${CONDA_PREFIX}/share/max"
  fi
  run_with_mojo
fi

echo "mojo not found; install pixi deps, set FALA_PIXI_ENV, or put mojo on PATH" >&2
exit 1
