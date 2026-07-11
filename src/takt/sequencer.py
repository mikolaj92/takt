"""TaktSequencer — dyskretny zegar wykonawczy.

Jeden takt = przesunięcie okna próbkowania na kolejny węzeł.
Napędza kaskadę regulatorów L0..Ln-1.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Any, Iterator

from .plant import ControlledPlant
from .regulator import CascadeRegulator
from .types import FalaWave, OutgoingSignals, StateNode


@dataclass
class TaktResult:
    """Wynik jednego taktu."""

    tact: int
    node: StateNode[Any]
    signals: OutgoingSignals
    descending_wave: FalaWave | None = None


@dataclass
class TaktSequencer:
    """Sekwencer taktów.

    - plant: dostarcza sekwencję węzłów (sequential_scan)
    - root_regulator: najwyższy regulator (L_n-1). Musi mieć child_loop aż do L0.
    - waves: aktualny kontekst fal między warstwami
    """

    plant: ControlledPlant[Any]
    root_regulator: CascadeRegulator
    _tact: int = field(default=0, init=False)
    _last_results: list[TaktResult] = field(default_factory=list, init=False, repr=False)

    def __post_init__(self) -> None:
        if self.root_regulator.parent_loop is not None:
            # root nie powinien mieć parenta
            self.root_regulator.parent_loop = None

    @property
    def current_tact(self) -> int:
        return self._tact

    def reset(self) -> None:
        self._tact = 0
        self._last_results.clear()

    def run_one_tact(self, incoming_top_wave: FalaWave | None = None) -> TaktResult:
        """Wykonaj jeden takt: weź następny węzeł, przepuść przez kaskadę."""
        nodes = list(self.plant.sequential_scan())
        if not nodes:
            raise RuntimeError("Plant zwrócił pusty skan — brak węzłów")

        # Bierzemy węzeł o indeksie _tact (mod len dla prostoty; w realu reset lub finite scan)
        idx = self._tact % len(nodes)
        node = nodes[idx]

        # Przepuszczamy od roota w dół (rekurencyjnie przez child_loop)
        result = self._evaluate_cascade(node, self.root_regulator, incoming_top_wave)

        self._tact += 1
        self._last_results.append(result)
        return result

    def _evaluate_cascade(
        self,
        node: StateNode[Any],
        regulator: CascadeRegulator,
        incoming: FalaWave | None,
    ) -> TaktResult:
        """Rekurencyjna ewaluacja kaskady dla węzła.

        Zaczynamy od najwyższego regulatora.
        Fala zstępująca schodzi w dół.
        """
        out = regulator.evaluate(node, incoming)

        # Jeśli ten regulator ma dziecko i węzeł ma dzieci — przekaż falę w dół
        descending = out.ascending_wave  # domyślnie ascending staje się kontekstem dla niżej
        if regulator.child_loop is not None and node.has_children():
            # Budujemy falę zstępującą z kontekstu tego poziomu
            child_wave = FalaWave(
                wave_id=f"desc_{uuid.uuid4().hex[:12]}",
                layer=regulator.child_loop.layer,
                source_id=regulator.name or f"reg_L{regulator.layer}",
                target_id=None,
                constraints=out.ascending_wave.constraints if out.ascending_wave else {},
                context={"from_layer": regulator.layer, "node": node.id},
                metadata={"propagated": True},
            )
            # Ewaluacja dziecka (na tym samym węźle — dziecko regulatora dostaje ten sam node,
            # ale jego dzieci dostaną falę przy niższych poziomach)
            child_out = regulator.child_loop.evaluate(node, child_wave)
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            merged_act = None
            if not merged_il:
                merged_act = child_out.actuation or out.actuation
            merged_wave = child_out.ascending_wave or out.ascending_wave
            out = OutgoingSignals(
                error=out.error,
                actuation=merged_act,
                interlock=merged_il,
                telemetry=merged_tele,
                ascending_wave=merged_wave,
            )
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            merged_act = None
            if not merged_il:
                merged_act = child_out.actuation or out.actuation
            merged_wave = child_out.ascending_wave or out.ascending_wave
            out = OutgoingSignals(
                error=out.error,
                actuation=merged_act,
                interlock=merged_il,
                telemetry=merged_tele,
                ascending_wave=merged_wave,
            )
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            merged_act = None
            if not merged_il:
                merged_act = child_out.actuation or out.actuation
            merged_wave = child_out.ascending_wave or out.ascending_wave
            out = OutgoingSignals(
                error=out.error,
                actuation=merged_act,
                interlock=merged_il,
                telemetry=merged_tele,
                ascending_wave=merged_wave,
            )
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            merged_act = None
            if not merged_il:
                merged_act = child_out.actuation or out.actuation
            merged_wave = child_out.ascending_wave or out.ascending_wave
            out = OutgoingSignals(
                error=out.error,
                actuation=merged_act,
                interlock=merged_il,
                telemetry=merged_tele,
                ascending_wave=merged_wave,
            )
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            merged_act = None
            if not merged_il:
                merged_act = child_out.actuation or out.actuation
            merged_wave = child_out.ascending_wave or out.ascending_wave
            out = OutgoingSignals(
                error=out.error,
                actuation=merged_act,
                interlock=merged_il,
                telemetry=merged_tele,
                ascending_wave=merged_wave,
            )
            # Zbuduj scalony wynik (OutgoingSignals jest frozen)
            merged_tele = list(out.telemetry) + list(child_out.telemetry)
            merged_il = child_out.interlock or out.interlock
            merged_act = None
            if not merged_il:
                merged_act = child_out.actuation or out.actuation
            merged_wave = child_out.ascending_wave or out.ascending_wave
            out = OutgoingSignals(
                error=out.error,
                actuation=merged_act,
                interlock=merged_il,
                telemetry=merged_tele,
                ascending_wave=merged_wave,
            )


        return TaktResult(
            tact=self._tact,
            node=node,
            signals=out,
            descending_wave=descending,
        )

    def run(self, steps: int, initial_wave: FalaWave | None = None) -> list[TaktResult]:
        """Uruchom N taktów."""
        results: list[TaktResult] = []
        wave = initial_wave
        for _ in range(steps):
            r = self.run_one_tact(wave)
            results.append(r)
            # Fala wstępująca z tego taktu może stać się kontekstem dla następnego
            wave = r.signals.ascending_wave
        return results


__all__ = ["TaktResult", "TaktSequencer"]
