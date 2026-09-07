from __future__ import annotations

import json
import re
import tomllib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
EVAL = ROOT / "examples" / "fixtures" / "cascade_evaluate.request.json"
INTERLOCK = ROOT / "examples" / "fixtures" / "cascade_interlock.request.json"


def _canonical_version() -> str:
    """Product version lives in pyproject.toml; tests must not hardcode the release."""
    with (ROOT / "pyproject.toml").open("rb") as fh:
        version = tomllib.load(fh)["project"]["version"]
    assert isinstance(version, str) and re.fullmatch(r"\d+\.\d+\.\d+", version), version
    return version


@pytest.fixture(autouse=True)
def _env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(ROOT)
    monkeypatch.setenv("TAKT_HOME", str(ROOT))


def test_cascade_step_evaluate_actuation() -> None:
    import takt

    result = takt.cascade_step(json.loads(EVAL.read_text(encoding="utf-8")))
    assert result.get("ok") is True
    assert result.get("outcome") in {"actuation", "stable", "interlock"}
    # high deviation plant → actuation expected for fixture value 0.8
    assert result["outcome"] == "actuation"
    assert result["node_id"] == "hunk:0"


def test_cascade_step_json_string() -> None:
    import takt

    result = takt.cascade_step(EVAL.read_text(encoding="utf-8"))
    assert "signals" in result and "events" in result


def test_product_stamps_match_canonical_pyproject_version() -> None:
    """#43: derived stamps follow [project].version; tests never hardcode the release."""
    version = _canonical_version()
    pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    pixi = (ROOT / "pixi.toml").read_text(encoding="utf-8")
    init_py = (ROOT / "python" / "takt" / "__init__.py").read_text(encoding="utf-8")
    init_mojo = (ROOT / "mojo" / "takt" / "__init__.mojo").read_text(encoding="utf-8")
    fala_pkg = (ROOT / "examples" / "fala-integration" / "fala-package.toml").read_text(
        encoding="utf-8"
    )
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")

    assert f'version = "{version}"' in pyproject
    assert f'version = "{version}"' in pixi
    assert f'__version__ = "{version}"' in init_py
    assert f'TAKT_VERSION = "{version}"' in init_mojo
    assert f'version = "{version}"' in fala_pkg
    assert f"**Version {version}**" in readme
    assert f"## {version}" in changelog.splitlines()
    assert f"--branch v{version}" in readme
    assert f"takt-{version}.tar.gz" in readme
    assert f"Canonical product version is `[project].version` in `pyproject.toml`" in readme


def test_product_is_mojo_030_not_stale_python_010() -> None:
    """Default clone must not look like develop's Python 0.1.0 / *-runtime tree."""
    version = _canonical_version()
    pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")

    assert "fala-runtime" not in pyproject
    assert "splot-runtime" not in pyproject
    assert "packages **`fala`** and **`splot`**" in readme
    assert "not `*-runtime`" in readme
    assert f"v{version}" in readme

    assert (ROOT / "python" / "takt" / "api.py").is_file()
    assert (ROOT / "mojo" / "takt" / "sequencer.mojo").is_file()
    assert not (ROOT / "src" / "takt").exists()

    assert "uv sync --extra dev" in readme


def test_product_stamps_are_030_not_leftover_mojo_only_020() -> None:
    """#25: main README/pixi must match the current product tree, not v0.2.0."""
    version = _canonical_version()
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    pixi = (ROOT / "pixi.toml").read_text(encoding="utf-8")

    assert 'version = "0.2.0"' not in pixi
    assert "**Version 0.2.0**" not in readme
    assert "There is no Python runtime product tree" not in readme
    assert "Get Mojo-only Takt (0.2.0)" not in readme
    assert "--branch v0.2.0" not in readme
    assert "takt-0.2.0.tar.gz" not in readme
    assert f"--branch v{version}" in readme
    assert f"takt-{version}.tar.gz" in readme
    assert "`python/takt`" in readme

    assert (ROOT / "python" / "takt" / "api.py").is_file()
    assert not (ROOT / "takt-0.2.0.tar.gz").exists()


def _repo_markdown() -> list[Path]:
    skip = {".git", ".lokay", ".pixi", "vendor", ".venv", "__pycache__", ".pytest_cache"}
    files: list[Path] = []
    for path in ROOT.rglob("*.md"):
        if any(part in skip for part in path.parts):
            continue
        files.append(path)
    return files


def test_docs_single_canonical_path() -> None:
    """#44: one-job / boundaries / Fala JSON live in docs/, not README or examples."""
    conceptual = (ROOT / "docs" / "CONCEPTUAL_MODEL.md").read_text(encoding="utf-8")
    fala = (ROOT / "docs" / "FALA_INTEGRATION.md").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    fala_ex = (ROOT / "examples" / "fala-integration" / "README.md").read_text(
        encoding="utf-8"
    )
    multi_ex = (ROOT / "examples" / "multi-organ" / "README.md").read_text(
        encoding="utf-8"
    )

    one_job = (
        "Stabilize hierarchical state, tact by tact, under descending constraints and"
    )
    stale_one_job = (
        "Stabilize hierarchical state, tact by tact — descending constraints"
    )
    boundaries = "| Outside Takt (host) | Inside Takt |"
    json_fence = re.compile(r"```json\b.*?```", re.DOTALL | re.IGNORECASE)

    assert "## One job" in conceptual
    assert one_job in conceptual
    assert stale_one_job not in conceptual
    assert boundaries in conceptual
    assert "## Fusion (local)" in conceptual
    assert "## Core abstractions" in conceptual

    assert "docs/CONCEPTUAL_MODEL.md" in readme
    assert "docs/FALA_INTEGRATION.md" in readme
    assert "## Layout" in readme
    assert "Get Takt" in readme
    assert "## Quick proof" in readme
    assert "## One job" not in readme
    assert one_job not in readme
    assert stale_one_job not in readme
    assert boundaries not in readme
    assert "## Fusion (local)" not in readme
    assert "## Boundaries" not in readme

    for path, text in (
        (ROOT / "README.md", readme),
        (ROOT / "examples" / "fala-integration" / "README.md", fala_ex),
        (ROOT / "examples" / "multi-organ" / "README.md", multi_ex),
    ):
        assert json_fence.search(text) is None, f"{path} copies JSON schema"

    assert "docs/FALA_INTEGRATION.md" in fala_ex
    assert "docs/CONCEPTUAL_MODEL.md" in fala_ex
    assert "docs/FALA_INTEGRATION.md" in multi_ex
    assert "docs/CONCEPTUAL_MODEL.md" in multi_ex

    assert '"mode": "evaluate"' in fala
    assert "TAKT_REQUEST_PATH" in fala
    assert "FALA_EFFECTOR_INPUT_DIR" in fala
    assert "plant_nodes" in fala
    assert "raw_signals" in fala

    for path in _repo_markdown():
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        if path.name != "CONCEPTUAL_MODEL.md":
            assert one_job not in text, f"one-job quote leaked into {rel}"
            assert stale_one_job not in text, f"stale one-job leaked into {rel}"
            assert boundaries not in text, f"boundaries table leaked into {rel}"
        if path.name != "FALA_INTEGRATION.md":
            assert json_fence.search(text) is None, f"JSON schema fence in {rel}"
