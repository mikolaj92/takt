#!/usr/bin/env bash
# Fala-compatible subprocess entry for Takt cascade step (Mojo).
# Expects Fala effector env (FALA_EFFECTOR_*) or TAKT_REQUEST_PATH.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

pixi_bin="${FALA_PIXI_ENV:-}"
if [[ -z "$pixi_bin" ]]; then
  if [[ -x "$root/.pixi/envs/default/bin/mojo" ]]; then
    pixi_bin="$root/.pixi/envs/default/bin"
  elif [[ -x "$root/../Fala/.pixi/envs/default/bin/mojo" ]]; then
    pixi_bin="$root/../Fala/.pixi/envs/default/bin"
  elif [[ -x "$root/../Splot/.pixi/envs/default/bin/mojo" ]]; then
    pixi_bin="$root/../Splot/.pixi/envs/default/bin"
  fi
fi
if [[ -n "$pixi_bin" ]]; then
  export PATH="$pixi_bin:${PATH:-/usr/bin:/bin}"
  if [[ -z "${CONDA_PREFIX:-}" ]]; then
    export CONDA_PREFIX="$(cd "$pixi_bin/.." && pwd)"
  fi
  if [[ -z "${MODULAR_HOME:-}" ]]; then
    export MODULAR_HOME="${CONDA_PREFIX}/share/max"
  fi
fi

if ! command -v mojo >/dev/null 2>&1; then
  echo '{"ok":false,"error":"mojo not found"}' >&2
  exit 127
fi
cd "$root"
exec mojo run -I mojo mojo/takt/step_main.mojo
