"""SplotFusionUnit — komponent fuzji i redukcji entropii wewnątrz regulatora.

Używa `splot` do skonsolidowania surowych sygnałów (RawSignal) w jeden
Wektor Aberracji (ErrorSignal) o zredukowanej entropii.
"""
from __future__ import annotations

import hashlib
import uuid
from typing import Any

from splot import run_round  # type: ignore[import-untyped]

from .types import ErrorSignal, RawSignal


class SplotFusionUnit:
    """Procesor decyzyjny używający splot do redukcji sygnałów.

    Strict: jeśli splot zwróci wysoką niepewność (uncertainty), regulator
    wyżej w hierarchii zdecyduje o interlocku.
    """

    def __init__(self, profile: dict[str, Any] | None = None) -> None:
        # Minimalny profil fuzji numerycznej odchyleń.
        # Jeden sygnał "aberration" z pola deviation obserwacji.
        # Używa constrained_weighted_score + reduce mean gdy potrzeba.
        self.profile: dict[str, Any] = profile or {
            "version": 1,
            "id": "takt_aberration_fusion",
            "mode": "select_one",
            "objective": {"id": "aberration_vector"},
            "signals": [
                {
                    "id": "aberration",
                    "provider": "observation.value",
                    "field": "deviation",
                    "weight": 1.0,
                    "reduce": "mean",  # średnia gdy wiele obserwacji tej samej fali
                }
            ],
            "decision": {"policy": "constrained_weighted_score"},
            "uncertainty": {
                "when_close": "select_best_anyway",
                "when_no_candidate": "fallback",
            },
        }

    def _mk_observation(self, sig: RawSignal, idx: int) -> dict[str, Any]:
        """Mapuj RawSignal na obserwację splot."""
        wave = sig.signal_id or f"{sig.node_id}:{sig.detector}"
        return {
            "id": f"obs_{idx}_{sig.signal_id}",
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
        """Jeden kandydat reprezentujący 'wektor aberracji'."""
        return {"id": "aberration_vector", "kind": "error_vector"}

    def fuse(
        self,
        raw_signals: list[RawSignal],
        node_id: str,
        now: str | None = None,
    ) -> ErrorSignal:
        """Zredukuj listę surowych sygnałów do jednego ErrorSignal.

        Zwraca ErrorSignal z:
        - aberration = skonsolidowana wartość (z sygnału splot)
        - confidence
        - residual_entropy = uncertainty.value z raportu
        """
        if not raw_signals:
            # Brak sygnałów → zerowy błąd, pełna pewność, zerowa entropia
            return ErrorSignal(
                vector_id=f"err_{uuid.uuid4().hex[:12]}",
                node_id=node_id,
                aberration=0.0,
                confidence=1.0,
                residual_entropy=0.0,
                contributing_signals=[],
                metadata={"source": "no_signals"},
            )

        observations = [self._mk_observation(s, i) for i, s in enumerate(raw_signals)]
        candidates = [self._mk_candidate()]

        result = run_round(
            self.profile,
            observations=observations,
            candidates=candidates,
            now=now or "2026-07-11T00:00:00+00:00",
        )

        report = result.report
        decision = report.decision or {}
        uncertainty = report.uncertainty or {}

        # Wyciągamy skonsolidowaną wartość aberracji z ewaluacji
        # (pierwszy sygnał w pierwszej ewaluacji)
        evaluations = report.evaluations or []
        aberration_value = 0.0
        if evaluations:
            sigs = evaluations[0].get("signals") or []
            if sigs:
                aberration_value = float(sigs[0].get("value", 0.0))

        # Pewność z decyzji lub 1 - uncertainty
        conf = float(decision.get("confidence", 1.0 - float(uncertainty.get("value", 0.0))))

        residual = float(uncertainty.get("value", 0.0))

        contrib = [s.signal_id for s in raw_signals]

        return ErrorSignal(
            vector_id=f"err_{uuid.uuid4().hex[:12]}",
            node_id=node_id,
            aberration=aberration_value,
            confidence=max(0.0, min(1.0, conf)),
            residual_entropy=max(0.0, min(1.0, residual)),
            contributing_signals=contrib,
            metadata={
                "splot_round_id": report.round_id,
                "splot_profile_id": report.profile_id,
                "splot_decision": decision,
                "splot_uncertainty": uncertainty,
            },
        )


__all__ = ["SplotFusionUnit"]
