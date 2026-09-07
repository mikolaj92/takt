from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
HELPER = TOOLS / "lib" / "mojo_env.sh"


def test_mojo_discovery_is_single_source() -> None:
    helper = HELPER.read_text(encoding="utf-8")
    mojo_run = (TOOLS / "mojo_run.sh").read_text(encoding="utf-8")
    takt_step = (TOOLS / "takt_step.sh").read_text(encoding="utf-8")
    setup = (TOOLS / "setup_ember_json.sh").read_text(encoding="utf-8")

    fala = "../Fala/.pixi/envs/default/bin"
    splot = "../Splot/.pixi/envs/default/bin"
    local = ".pixi/envs/default/bin"
    assert "Single source" in helper or "single source" in helper
    assert fala in helper and splot in helper and local in helper
    assert "FALA_PIXI_ENV" in helper
    for text in (mojo_run, takt_step):
        assert "tools/lib/mojo_env.sh" in text
        assert fala not in text
        assert splot not in text
        assert "pixi run -- bash -c" not in text
    assert "takt_ensure_flock" in setup
    assert "vendor/.emberjson.setup.lock" in setup
    assert setup.startswith("#!/bin/sh")
    assert mojo_run.startswith("#!/bin/sh")
    assert takt_step.startswith("#!/bin/sh")


def test_takt_ensure_flock_serializes_critical_section(tmp_path: Path) -> None:
    lock = tmp_path / "vendor" / ".emberjson.setup.lock"
    log = tmp_path / "order.log"
    worker = tmp_path / "worker.sh"
    worker.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        f'. "{HELPER}"\n'
        f'takt_ensure_flock "{lock}" "$0" "$@" || exit $?\n'
        f'echo start >> "{log}"\n'
        "sleep 0.15\n"
        f'echo end >> "{log}"\n',
        encoding="utf-8",
    )
    worker.chmod(0o755)
    env = os.environ.copy()
    env.pop("TAKT_FLOCK_HELD", None)
    processes = [subprocess.Popen([str(worker)], env=env) for _ in range(4)]
    assert [process.wait(timeout=20) for process in processes] == [0] * len(processes)
    assert log.read_text(encoding="utf-8").splitlines() == ["start", "end"] * 4
