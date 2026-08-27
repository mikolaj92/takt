"""Lock develop as historical Python 0.1.0 — not Mojo 0.3.1 from main.

File-stamp only: no fala-runtime / splot-runtime import.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_develop_is_historical_python_010_not_mojo_031() -> None:
    pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")

    assert 'version = "0.1.0"' in pyproject
    assert "fala-runtime" in pyproject
    assert "splot-runtime" in pyproject
    assert 'path = "../Fala"' in pyproject
    assert 'path = "../splot"' in pyproject
    assert 'version = "0.3.1"' not in pyproject

    assert "historical Python 0.1.0" in readme
    assert "v0.3.1" in readme
    assert "not the product" in readme
    assert "packages **`fala`** and **`splot`**" in readme
    assert "not `*-runtime`" in readme
    assert "--branch v0.3.1" in readme

    assert (ROOT / "src" / "takt").is_dir()
    assert not (ROOT / "mojo" / "takt").exists()
    assert not (ROOT / "python" / "takt").exists()
