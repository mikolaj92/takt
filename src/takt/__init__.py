"""takt: generyczny silnik kaskadowego przetwarzania hierarchicznego.

Transport: fala (pion/poziom). Redukcja entropii: splot.

Ścisłe nazewnictwo cybernetyczne.
"""
from __future__ import annotations

from .fusion import SplotFusionUnit
from .homeostat import EssentialVariable, Homeostat
from .plant import ControlledPlant, MathTreePlant, TreeNode
from .regulator import CascadeRegulator
from .sequencer import TaktResult, TaktSequencer
from .builder import build_cascade
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

__all__ = [
    "StateNode",
    "FalaWave",
    "RawSignal",
    "ErrorSignal",
    "Actuation",
    "SafetyInterlock",
    "Telemetry",
    "OutgoingSignals",
    "EssentialVariable",
    "Homeostat",
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
