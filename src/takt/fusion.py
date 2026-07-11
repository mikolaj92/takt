"""SplotFusionUnit — opcjonalny komponent fuzji i redukcji entropii.

Domyślnie używa `splot` (jeśli zainstalowany).
Jeśli splot nie jest dostępny, stosuje prosty fallback (średnia ważona odchyleń).
Splot jest opcjonalny: takt zawsze wymaga fali jako podłoża transportu.
"""

from __future__ import annotations

import uuid
from typing import Any

from .types import ErrorSignal, RawSignal

_HAS_SPLOT = False
try:
    from splot import run_round  # type: ignore[import-untyped]
    _HAS_SPLOT = True
except ImportError:
    run_round = None  # type: ignore[assignment]


class SplotFusionUnit:
    """Procesor decyzyjny.

    Gdy splot-runtime jest zainstalowany: używa constrained_weighted_score + reduce.
    Gdy nie ma splotu: prosty fallback — średnia ważona raw signals.
    """

    def __init__(self, profile: dict[str, Any] | None = None) -> None:
        self.profile: dict[str, Any] = profile or {
            "id": "fallback_aberration",
            "mode": "regulate",
            "signals": [{"id": "aberration", "weight": 1.0, "prefer": "lower"}],
        }
    def _looks_like_splot_profile(self, p: dict[str, Any]) -> bool:
        return isinstance(p, dict) and "version" in p

    def fuse(
        self,
        raw_signals: list[RawSignal],
        node_id: str,
        now: str | None = None,
    ) -> ErrorSignal:
        """Zredukuj listę surowych sygnałów do jednego ErrorSignal.

        Jeśli dostępny jest splot — używa go do redukcji entropii.
        W przeciwnym razie — prosty fallback (średnia ważona).
        """
        if not raw_signals:
            return ErrorSignal(
                vector_id=f"err_{uuid.uuid4().hex[:12]}",
                node_id=node_id,
                aberration=0.0,
                confidence=1.0,
                residual_entropy=0.0,
                contributing_signals=[],
                metadata={"reducer": "empty"},
            )

        if (
            _HAS_SPLOT
            and run_round is not None
            and self._looks_like_splot_profile(self.profile)
        ):
            return self._fuse_with_splot(raw_signals, node_id, now)

        return self._fuse_fallback(raw_signals, node_id)

    def _fuse_with_splot(
        self,
        raw_signals: list[RawSignal],
        node_id: str,
        now: str | None,
    ) -> ErrorSignal:
        observations = [
            self._mk_observation(sig, i) for i, sig in enumerate(raw_signals)
        ]
        candidates = [self._mk_candidate()]
        result = run_round(
            profile=self.profile,
            observations=observations,
            candidates=candidates,
            now=now or "2026-01-01T00:00:00Z",
        )
        decision = result.get("decision", {}) if isinstance(result, dict) else {}
        eval_ = (decision.get("evaluations") or [{}])[0] if decision else {}
        aberration = float(eval_.get("score", 0.0) or 0.0)
        confidence = float(eval_.get("confidence", 0.7) or 0.7)
        residual = float(result.get("uncertainty", 0.5)) if isinstance(result, dict) else 0.5

        return ErrorSignal(
            vector_id=f"err_{uuid.uuid4().hex[:12]}",
            node_id=node_id,
            aberration=aberration,
            confidence=confidence,
            residual_entropy=residual,
            contributing_signals=[s.signal_id for s in raw_signals],
            metadata={
                "reducer": "splot",
                "raw_count": len(raw_signals),
                "profile_id": self.profile.get("id"),
            },
        )

    def _fuse_fallback(self, raw_signals: list[RawSignal], node_id: str) -> ErrorSignal:
        """Prosty reduktor gdy brak splotu.

        Średnia ważona odchyleń (deviation), confidence = min confidence z sygnałów.
        """
        total_weight = 0.0
        weighted_sum = 0.0
        min_conf = 1.0
        ids: list[str] = []

        for sig in raw_signals:
            w = 1.0
            weighted_sum += sig.deviation * w
            total_weight += w
            if sig.confidence < min_conf:
                min_conf = sig.confidence
            ids.append(sig.signal_id)

        aberration = weighted_sum / total_weight if total_weight > 0 else 0.0
        confidence = min_conf if raw_signals else 1.0
        residual = max(0.3, 1.0 - confidence)

        return ErrorSignal(
            vector_id=f"err_{uuid.uuid4().hex[:12]}",
            node_id=node_id,
            aberration=aberration,
            confidence=confidence,
            residual_entropy=residual,
            contributing_signals=ids,
            metadata={"reducer": "fallback", "raw_count": len(raw_signals)},
        )

    # --- helpers for splot path (only called when splot present) ---

    def _mk_observation(self, sig: RawSignal, idx: int) -> dict[str, Any]:
        wave = sig.signal_id or f"{sig.node_id}:{sig.detector}"
        return {
            "id": f"sig_{idx}",
            "wave_id": wave,
            "values": {"deviation": float(sig.deviation)},
            "confidence": float(sig.confidence),
            "metadata": {
                "node_id": sig.node_id,
                "detector": sig.detector,
                "evidence": dict(sig.evidence),
            },
        }

    def _mk_candidate(self) -> dict[str, Any]:
        return {"id": "aberration_vector", "kind": "error_vector"}


__all__ = ["SplotFusionUnit"]
