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
