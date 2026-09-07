# Sourced, not executed.
# POSIX /bin/sh on purpose: Python _build.py invokes setup_ember_json.sh with
# `sh`, and the bash-era entrypoints now source this helper too. One shebang
# family, one candidate list.
#
# Single source of Mojo toolchain discovery for tools/mojo_run.sh and
# tools/takt_step.sh. Do not copy the candidate list into those entrypoints.
#
# Candidates, in order:
#   $FALA_PIXI_ENV
#   $root/.pixi/envs/default/bin
#   $root/../Fala/.pixi/envs/default/bin
#   $root/../Splot/.pixi/envs/default/bin
#   mojo already on PATH
#
# takt_ensure_flock: exclusive cross-process lock for EmberJson setup.
# util-linux flock(1) if present, else python3 fcntl, else mkdir spinlock.

takt_setup_mojo_env() {
  _takt_candidate=$1
  if [ -n "$_takt_candidate" ] && [ -x "$_takt_candidate/mojo" ]; then
    PATH="$_takt_candidate:${PATH:-/usr/bin:/bin}"
    export PATH
    if [ -z "${CONDA_PREFIX:-}" ]; then
      CONDA_PREFIX=$(CDPATH= cd -- "$_takt_candidate/.." && pwd)
      export CONDA_PREFIX
    fi
    if [ -z "${MODULAR_HOME:-}" ]; then
      MODULAR_HOME="${CONDA_PREFIX}/share/max"
      export MODULAR_HOME
    fi
    return 0
  fi
  return 1
}

takt_discover_mojo() {
  _takt_root=$1
  for _takt_candidate in \
    "${FALA_PIXI_ENV:-}" \
    "$_takt_root/.pixi/envs/default/bin" \
    "$_takt_root/../Fala/.pixi/envs/default/bin" \
    "$_takt_root/../Splot/.pixi/envs/default/bin"
  do
    if takt_setup_mojo_env "$_takt_candidate"; then
      return 0
    fi
  done
  if command -v mojo >/dev/null 2>&1; then
    if [ -z "${MODULAR_HOME:-}" ] && [ -n "${CONDA_PREFIX:-}" ]; then
      MODULAR_HOME="${CONDA_PREFIX}/share/max"
      export MODULAR_HOME
    fi
    return 0
  fi
  return 1
}

# Hold an exclusive lock for the rest of this process.
# Must be called at top-level (exec-based backends replace the process).
takt_ensure_flock() {
  _takt_lock=$1
  _takt_script=$2
  shift 2
  if [ -n "${TAKT_FLOCK_HELD:-}" ]; then
    return 0
  fi
  TAKT_FLOCK_HELD=1
  export TAKT_FLOCK_HELD
  mkdir -p "$(dirname -- "$_takt_lock")"

  if command -v flock >/dev/null 2>&1; then
    exec flock "$_takt_lock" "$_takt_script" "$@"
  fi

  _takt_python=
  if command -v python3 >/dev/null 2>&1; then
    _takt_python=python3
  elif [ -x /usr/bin/python3 ]; then
    _takt_python=/usr/bin/python3
  fi
  if [ -n "$_takt_python" ]; then
    exec "$_takt_python" -c '
import fcntl, os, subprocess, sys
lock_path = sys.argv[1]
os.makedirs(os.path.dirname(lock_path) or ".", exist_ok=True)
fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
raise SystemExit(subprocess.call(sys.argv[2:]))
' "$_takt_lock" "$_takt_script" "$@"
  fi

  # ponytail: mkdir spinlock when flock(1) and python3 are both missing.
  # Stale after kill -9: rmdir the .d directory.
  _takt_lockdir=${_takt_lock}.d
  while ! mkdir "$_takt_lockdir" 2>/dev/null; do
    sleep 0.1 2>/dev/null || sleep 1
  done
  trap 'rmdir "$_takt_lockdir" 2>/dev/null || true' EXIT INT TERM
  return 0
}
