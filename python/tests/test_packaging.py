from __future__ import annotations

import subprocess
import sys
import tarfile
import tomllib
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]


def test_sdist_and_direct_wheel_have_matching_resources(tmp_path: Path) -> None:
    with (ROOT / "pyproject.toml").open("rb") as stream:
        mapping = tomllib.load(stream)["tool"]["hatch"]["build"]["targets"]["wheel"][
            "force-include"
        ]

    required = (
        "mojo/takt/__init__.mojo",
        "mojo/takt/sequencer.mojo",
        "mojo/takt/step_main.mojo",
        "tools/setup_ember_json.sh",
        "tools/lib/mojo_env.sh",
        "patches/emberjson-mojo-1.0.patch",
    )
    expected = set()
    for resource in required:
        source = PurePosixPath(resource)
        expected.add(str(PurePosixPath(mapping[source.parts[0]], *source.parts[1:])))
    expected.add("takt/_native.mojo")

    def build(source: Path, kind: str, output: Path) -> Path:
        result = subprocess.run(
            [
                "uv",
                "build",
                str(source),
                f"--{kind}",
                "--out-dir",
                str(output),
                "--python",
                sys.executable,
            ],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        artifacts = list(output.glob("*.tar.gz" if kind == "sdist" else "*.whl"))
        assert len(artifacts) == 1, artifacts
        return artifacts[0]

    sdist = build(ROOT, "sdist", tmp_path / "sdist")
    unpacked = tmp_path / "unpacked"
    with tarfile.open(sdist) as archive:
        members = {
            PurePosixPath(member.name)
            for member in archive.getmembers()
            if member.isfile()
        }
        roots = {member.parts[0] for member in members}
        assert len(roots) == 1, roots
        source_root = roots.pop()
        for resource in (*required, "python/takt/_native.mojo", "pyproject.toml"):
            assert PurePosixPath(source_root, resource) in members, resource
        archive.extractall(unpacked, filter="data")

    rebuilt = build(unpacked / source_root, "wheel", tmp_path / "rebuilt")
    direct = build(ROOT, "wheel", tmp_path / "direct")
    prefixes = tuple(
        f"{path.rstrip('/')}/"
        for source in ("mojo", "tools", "patches")
        for path in (source, mapping[source])
    )
    resource_paths = []
    for wheel in (direct, rebuilt):
        with zipfile.ZipFile(wheel) as archive:
            names = set(archive.namelist())
        assert expected <= names, (wheel.name, expected - names)
        for source in ("mojo", "tools", "patches"):
            if PurePosixPath(mapping[source]).parts[0] == "takt":
                unexpected = {name for name in names if name.startswith(f"{source}/")}
                assert not unexpected, (wheel.name, unexpected)
        resource_paths.append({name for name in names if name.startswith(prefixes)})
    assert resource_paths[0] == resource_paths[1]
