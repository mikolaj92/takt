"""takt: generyczny silnik kaskadowego przetwarzania hierarchicznego.

Pakiet używa lokalnych struktur `Wave`; Fala jest opcjonalnym zewnętrznym
adapterem/runtime'em, a Splot opcjonalnym reduktorem sygnałów.
"""

from __future__ import annotations

from .fusion import SplotFusionUnit
from .homeostat import EssentialVariable, ProfilHomeostatyczny
from .plant import ControlledPlant, MathTreePlant, TreeNode
from .regulator import CascadeRegulator
from .sequencer import TaktResult, TaktSequencer
from .builder import build_cascade
from .types import (
    Actuation,
    ErrorSignal,
    Wave,
    OutgoingSignals,
    RawSignal,
    SafetyInterlock,
    StateNode,
    Telemetry,
)

__all__ = [
    "StateNode",
    "Wave",
    "RawSignal",
    "ErrorSignal",
    "Actuation",
    "SafetyInterlock",
    "Telemetry",
    "OutgoingSignals",
    "EssentialVariable",
    "ProfilHomeostatyczny",
    "ControlledPlant",
    "MathTreePlant",
    "TreeNode",
    "SplotFusionUnit",
    "CascadeRegulator",
    "TaktResult",
    "TaktSequencer",
    "build_cascade",
]

__version__ = "0.1.0"
