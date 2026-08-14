from __future__ import annotations

import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
EVAL = ROOT / "examples" / "fixtures" / "cascade_evaluate.request.json"
INTERLOCK = ROOT / "examples" / "fixtures" / "cascade_interlock.request.json"


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


def test_product_stamps_are_030_not_leftover_020() -> None:
    """main must present 0.3.0 + python/takt, not leftover Mojo-only 0.2.0 stamps."""
    pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    pixi = (ROOT / "pixi.toml").read_text(encoding="utf-8")
    init_py = (ROOT / "python" / "takt" / "__init__.py").read_text(encoding="utf-8")
    init_mojo = (ROOT / "mojo" / "takt" / "__init__.mojo").read_text(encoding="utf-8")
    fala_pkg = (ROOT / "examples" / "fala-integration" / "fala-package.toml").read_text(
        encoding="utf-8"
    )

    assert 'version = "0.3.0"' in pyproject
    assert 'version = "0.3.0"' in pixi
    assert 'version = "0.3.0"' in fala_pkg
    assert '__version__ = "0.3.0"' in init_py
    assert 'TAKT_VERSION = "0.3.0"' in init_mojo
    assert "**Version 0.3.0**" in readme
    assert "v0.3.0" in readme
    assert "takt-0.3.0.tar.gz" in readme
    assert "python/takt" in readme

    assert 'version = "0.2.0"' not in pixi
    assert 'TAKT_VERSION = "0.2.0"' not in init_mojo
    assert "**Version 0.2.0**" not in readme
    assert "--branch v0.2.0" not in readme
    assert "takt-0.2.0.tar.gz" not in readme
    assert "There is no Python runtime product tree" not in readme
    assert "**none** in the product tree" not in readme

    assert (ROOT / "python" / "takt" / "api.py").is_file()
    assert (ROOT / "mojo" / "takt" / "sequencer.mojo").is_file()
