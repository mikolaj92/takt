"""CascadeRegulator — pojedyncza pętla sterowania w hierarchii n-poziomowej.

- evaluate(node, incoming_wave) -> OutgoingSignals
- Używa SplotFusionUnit do redukcji
- Respektuje ProfilHomeostatyczny (strict fail-closed, warstwa — nie mylić z runtime gate z Fala)
- Propaguje fale zstępujące / wstępujące
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Any

from .fusion import SplotFusionUnit
from .homeostat import ProfilHomeostatyczny
from .types import (
    Actuation,
    ErrorSignal,
    FalaWave,
    OutgoingSignals,
    RawSignal,
    SafetyInterlock,
    StateNode,
    Telemetry,
)


@dataclass
class CascadeRegulator:
    """Regulator kaskadowy dla jednego poziomu hierarchii.

    parent_loop: regulator nadrzędny (fala zstępująca stamtąd)
    child_loop: podrzędny (dla propagacji w dół)
    """

    layer: int
    homeostat: ProfilHomeostatyczny
    fusion: SplotFusionUnit = field(default_factory=SplotFusionUnit)
    parent_loop: CascadeRegulator | None = None
    child_loop: CascadeRegulator | None = None
    name: str | None = None

    # Lokalne detektory/efektory mogą wstrzykiwać surowe sygnały per-node
    _local_detectors: list = field(default_factory=list, repr=False)

    def register_detector(self, detector: Any) -> None:
        """Zarejestruj detektor lokalny (obiekt z metodą detect(node) -> list[RawSignal])."""
        self._local_detectors.append(detector)

    def _collect_raw_signals(self, node: StateNode[Any], incoming: FalaWave | None) -> list[RawSignal]:
        signals: list[RawSignal] = []

        # 1. Sygnały z fali zstępującej (z parent)
        if incoming and incoming.constraints:
            for key, val in incoming.constraints.items():
                try:
                    dev = float(val)
                except (TypeError, ValueError):
                    continue
                signals.append(
                    RawSignal(
                        signal_id=f"wave:{incoming.wave_id}:{key}",
                        node_id=node.id,
                        detector="parent_wave",
                        deviation=dev,
                        confidence=0.95,
                        evidence={"source": "descending_wave", "key": key},
                    )
                )

        # 2. Sygnały z lokalnych detektorów
        for det in self._local_detectors:
            if hasattr(det, "detect"):
                try:
                    dets = det.detect(node) or []
                    for d in dets:
                        if isinstance(d, RawSignal):
                            signals.append(d)
                        elif isinstance(d, dict):
                            signals.append(RawSignal.model_validate(d))
                except Exception:
                    # Fail-safe: zły detektor nie psuje całego taktu
                    pass

        # 3. Domyślny sygnał na podstawie wartości węzła (dla czysto matematycznych testów)
        # Jeśli węzeł ma wartość numeryczną, traktujemy ją jako odchylenie.
        try:
            v = float(node.value)  # type: ignore[arg-type]
            if abs(v) > 1e-12:
                signals.append(
                    RawSignal(
                        signal_id=f"node_value:{node.id}",
                        node_id=node.id,
                        detector="intrinsic_value",
                        deviation=v,
                        confidence=0.8,
                        evidence={"value": v},
                    )
                )
        except (TypeError, ValueError):
            pass

        return signals

    def _build_descending_wave(self, node: StateNode[Any], parent_wave: FalaWave | None) -> FalaWave:
        """Buduje falę zstępującą dla dzieci na podstawie kontekstu + homeostatu."""
        constraints: dict[str, Any] = {}
        if parent_wave:
            constraints.update(parent_wave.constraints)

        # Dodaj ograniczenia z homeostatu (tolerancje jako górne limity aberracji)
        for vname, var in self.homeostat.variables.items():
            constraints.setdefault(f"homeostat.{vname}.tolerance", var.tolerance)
            constraints.setdefault(f"homeostat.{vname}.cutoff", var.cutoff)

        return FalaWave(
            wave_id=f"wave_L{self.layer}_{uuid.uuid4().hex[:8]}",
            layer=self.layer,
            source_id=self.name or f"reg_L{self.layer}",
            target_id=None,
            constraints=constraints,
            context={
                "layer": self.layer,
                "parent_wave": parent_wave.wave_id if parent_wave else None,
                "node_id": node.id,
            },
            metadata={"homeostat": self.homeostat.to_dict()},
        )

    def evaluate(self, node: StateNode[Any], incoming_wave: FalaWave | None = None) -> OutgoingSignals:
        """Główna metoda taktu dla tego poziomu.

        1. Zbierz surowe sygnały (z fali + detektorów + wartości węzła)
        2. Splot → ErrorSignal
        3. ProfilHomeostatyczny → decyzja: Actuation / Interlock / nic
        4. Przygotuj falę wstępującą + ewentualną falę zstępującą dla dzieci
        """
        raw = self._collect_raw_signals(node, incoming_wave)

        error = self.fusion.fuse(raw, node_id=node.id)

        # Strict fail-closed
        interlock: SafetyInterlock | None = None
        actuation: Actuation | None = None
        tel: list[Telemetry] = []

        if self.homeostat.should_interlock(error.residual_entropy, error.confidence):
            interlock = SafetyInterlock(
                interlock_id=f"il_{uuid.uuid4().hex[:12]}",
                node_id=node.id,
                reason="high_residual_entropy_or_low_confidence",
                residual_entropy=error.residual_entropy,
                blocked_signals=list(error.contributing_signals),
                metadata={"error_vector": error.model_dump()},
            )
            tel.append(
                Telemetry(
                    telemetry_id=f"tel_{uuid.uuid4().hex[:12]}",
                    node_id=node.id,
                    layer=self.layer,
                    kind="interlock",
                    payload={"reason": interlock.reason, "residual": interlock.residual_entropy},
                )
            )
        else:
            # Sprawdź czy aberration przekracza tolerancję którejś zmiennej krytycznej
            should_act = False
            for vname, var in self.homeostat.variables.items():
                if abs(error.aberration) > var.tolerance:
                    should_act = True
                    break
            # Jeśli nie ma zdefiniowanych zmiennych — akt na podstawie niezerowego błędu + pewności
            if not self.homeostat.variables:
                should_act = abs(error.aberration) > 1e-9 and error.confidence >= self.homeostat.min_confidence

            if should_act:
                actuation = Actuation(
                    actuation_id=f"act_{uuid.uuid4().hex[:12]}",
                    node_id=node.id,
                    command="correct_aberration",
                    parameters={"delta": error.aberration},
                    expected_delta=-error.aberration,
                    metadata={"error_vector": error.model_dump()},
                )
            # W przeciwnym razie — stabilny stan, brak impulsu

        # Fala wstępująca (ascending) — zawsze, z wynikiem
        ascending = FalaWave(
            wave_id=f"asc_{uuid.uuid4().hex[:12]}",
            layer=self.layer,
            source_id=node.id,
            target_id=self.parent_loop.name if self.parent_loop else None,
            constraints={"aberration": error.aberration, "confidence": error.confidence},
            context={"error_id": error.vector_id, "interlocked": interlock is not None},
            metadata={"residual_entropy": error.residual_entropy},
        )

        # Fala zstępująca dla dzieci (jeśli są)
        descending_for_child: FalaWave | None = None
        if node.has_children():
            descending_for_child = self._build_descending_wave(node, incoming_wave)

        tel.append(
            Telemetry(
                telemetry_id=f"tel_{uuid.uuid4().hex[:12]}",
                node_id=node.id,
                layer=self.layer,
                kind="evaluation",
                payload={
                    "error": error.model_dump(),
                    "actuation": actuation.model_dump() if actuation else None,
                    "interlock": interlock.model_dump() if interlock else None,
                },
                wave=ascending,
            )
        )

        return OutgoingSignals(
            error=error,
            actuation=actuation,
            interlock=interlock,
            telemetry=tel,
            ascending_wave=ascending,
        )


__all__ = ["CascadeRegulator"]
