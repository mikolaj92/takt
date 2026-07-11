"""Core abstract types for takt.

StateNode: abstract tree node for hierarchical state.
Fala-transported signal structures (descending/ascending waves, error signals,
actuations, interlocks, telemetry). No domain knowledge.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Generic, Iterator, Protocol, Sequence, TypeVar

from pydantic import BaseModel, ConfigDict, Field

# ----------------------------------------------------------------------------
# State hierarchy (n >= 2 layers)
# ----------------------------------------------------------------------------

T = TypeVar("T", covariant=True)
S = TypeVar("S", bound="StateNode")


class StateNode(Protocol, Generic[T]):
    """Abstrakcyjny węzeł w hierarchicznej strukturze stanu.

    Każdy węzeł reprezentuje autonomiczny fragment kontrolowanego środowiska.
    Relacje rodzic-dziecko definiują kaskadę poziomów (L0 ... Ln-1).

    Implementacje muszą być hashable/identyfikowalne i wspierać iterację dzieci
    w kolejności sekwencyjnej (dla sequential_scan).
    """

    @property
    def id(self) -> str: ...

    @property
    def value(self) -> T: ...

    def get_children(self) -> Sequence[StateNode[T]]: ...

    def has_children(self) -> bool: ...

    def __repr__(self) -> str: ...


# ----------------------------------------------------------------------------
# Fala signal structures (vertical/horizontal transport)
# ----------------------------------------------------------------------------

class FalaWave(BaseModel):
    """Fala zstępująca / wstępująca.

    Przenosi kontekst, ograniczenia lub telemetrię między warstwami regulatorów.
    Używana jako nośnik informacji w kanałach fala (zstępująca: constraints/context,
    wstępująca: telemetry/diagnostics).

    Zgodna z duchem fala: impulsy informacji przepływające przez kaskadę.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)

    wave_id: str = Field(..., description="Unikalny identyfikator fali (takt + ścieżka)")
    layer: int = Field(..., ge=0, description="Poziom hierarchii (0 = najniższy)")
    source_id: str = Field(..., description="Id węzła/regulatora źródłowego")
    target_id: str | None = Field(
        default=None, description="Id docelowego węzła (None = broadcast w dół)"
    )
    constraints: dict[str, Any] = Field(
        default_factory=dict, description="Ograniczenia / zmienne krytyczne z wyższych warstw"
    )
    context: dict[str, Any] = Field(
        default_factory=dict, description="Kontekst decyzyjny / stan nadrzędny"
    )
    metadata: dict[str, Any] = Field(default_factory=dict)


class RawSignal(BaseModel):
    """Surowy sygnał z detektora lokalnego lub efektora zewnętrznego.

    Potencjalnie szumny, sprzeczny. Przed redukcją przez splot.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)

    signal_id: str
    node_id: str
    detector: str
    deviation: float  # signed magnitude of detected error
    confidence: float = Field(..., ge=0.0, le=1.0)
    evidence: dict[str, Any] = Field(default_factory=dict)
    timestamp: str | None = None


class ErrorSignal(BaseModel):
    """Wektor aberracji (sygnał błędu) po redukcji entropii przez splot.

    Jednolity, skonsolidowany sygnał o zredukowanej entropii.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)

    vector_id: str
    node_id: str
    aberration: float  # consolidated error magnitude (can be signed)
    confidence: float = Field(..., ge=0.0, le=1.0)
    residual_entropy: float = Field(..., ge=0.0, le=1.0)
    contributing_signals: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class Actuation(BaseModel):
    """Impuls wykonawczy (Actuation).

    Zmiana stanu środowiska, gdy pewność > próg homeostatyczny i brak interlocku.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)

    actuation_id: str
    node_id: str
    command: str
    parameters: dict[str, Any] = Field(default_factory=dict)
    expected_delta: float | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class SafetyInterlock(BaseModel):
    """Mechanizm bezpieczeństwa (fail-closed).

    Aktywowany gdy splot nie jest w stanie zredukować entropii poniżej progu
    lub występuje nieredukowalna sprzeczność.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)

    interlock_id: str
    node_id: str
    reason: str
    residual_entropy: float
    blocked_signals: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class Telemetry(BaseModel):
    """Ślad diagnostyczny (fala wstępująca).

    Emitowany na zewnątrz lub do warstw nadrzędnych w przypadku interlocku
    lub dla audytu.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)

    telemetry_id: str
    node_id: str
    layer: int
    kind: str  # e.g. "interlock", "decision", "state_change"
    payload: dict[str, Any] = Field(default_factory=dict)
    wave: FalaWave | None = None


# ----------------------------------------------------------------------------
# Outgoing signals bundle from a regulator evaluation
# ----------------------------------------------------------------------------

@dataclass(frozen=True)
class OutgoingSignals:
    """Wynik evaluate() regulatora kaskadowego.

    Zawiera albo Actuation (gdy decyzja wykonawcza), albo SafetyInterlock,
    plus ewentualną falę wstępującą (telemetrię) i wektor błędu.
    """

    error: ErrorSignal | None = None
    actuation: Actuation | None = None
    interlock: SafetyInterlock | None = None
    telemetry: list[Telemetry] = field(default_factory=list)
    ascending_wave: FalaWave | None = None

    def has_actuation(self) -> bool:
        return self.actuation is not None and self.interlock is None

    def is_interlocked(self) -> bool:
        return self.interlock is not None


__all__ = [
    "StateNode",
    "FalaWave",
    "RawSignal",
    "ErrorSignal",
    "Actuation",
    "SafetyInterlock",
    "Telemetry",
    "OutgoingSignals",
]
