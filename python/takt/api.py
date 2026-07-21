"""Thin Python API over the Mojo cascade engine."""

from __future__ import annotations

import json
from typing import Any, Mapping

from takt._build import ensure_native


def cascade_step(request: str | Mapping[str, Any]) -> dict[str, Any]:
    """One cascade step — same JSON as ``tools/takt_step.sh``."""
    if isinstance(request, Mapping):
        payload = json.dumps(request)
    else:
        payload = request
    native = ensure_native()
    raw = native.cascade_step_json(payload)
    if not isinstance(raw, str):
        raw = str(raw)
    out = json.loads(raw)
    if not isinstance(out, dict):
        raise RuntimeError("takt: cascade_step result is not an object")
    return out
