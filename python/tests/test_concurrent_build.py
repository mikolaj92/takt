from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def test_concurrent_cold_native_build_is_serialized_and_atomic(tmp_path: Path) -> None:
    root = tmp_path / "takt-home"
    (root / "mojo" / "takt").mkdir(parents=True)
    (root / "mojo" / "takt" / "placeholder.mojo").write_text("", encoding="utf-8")
    (root / "patches").mkdir()
    (root / "patches" / "emberjson-test.patch").write_text("", encoding="utf-8")
    setup = root / "tools" / "setup_ember_json.sh"
    setup.parent.mkdir()
    setup.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "mkdir -p vendor/EmberJson/emberjson\n"
        "touch vendor/EmberJson/emberjson/__init__.mojo\n",
        encoding="utf-8",
    )
    setup.chmod(0o755)

    toolchain = root / ".pixi" / "envs" / "default"
    mojo = toolchain / "bin" / "mojo"
    mojo.parent.mkdir(parents=True)
    (toolchain / "lib" / "mojo").mkdir(parents=True)
    build_log = root / "builds.log"
    mojo.write_text(
        "#!/usr/bin/env python3\n"
        "import os, pathlib, sys, time\n"
        "args = sys.argv[1:]\n"
        "output = pathlib.Path(args[args.index('-o') + 1])\n"
        "time.sleep(0.1)\n"
        "output.write_bytes(b'complete-native-artifact')\n"
        "with pathlib.Path(os.environ['TAKT_BUILD_LOG']).open('a') as stream:\n"
        "    stream.write('build\\n')\n",
        encoding="utf-8",
    )
    mojo.chmod(0o755)

    env = os.environ.copy()
    env["PYTHONPATH"] = str(Path(__file__).resolve().parents[1])
    env["TAKT_HOME"] = str(root)
    env["TAKT_BUILD_LOG"] = str(build_log)
    env["TAKT_BUILD_CACHE"] = str(tmp_path / "native-cache")
    command = (
        sys.executable,
        "-c",
        "from pathlib import Path; from takt._build import _ensure_native_artifact; "
        "os = __import__('os'); path = _ensure_native_artifact(Path(os.environ['TAKT_HOME']), cache_dir=Path(os.environ['TAKT_BUILD_CACHE'])); "
        "assert path.read_bytes() == b'complete-native-artifact'",
    )
    processes = [subprocess.Popen(command, env=env) for _ in range(6)]

    assert [process.wait(timeout=20) for process in processes] == [0] * len(processes)
    assert build_log.read_text(encoding="utf-8").splitlines() == ["build"]
