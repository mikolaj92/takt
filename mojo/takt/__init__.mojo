"""takt: generic hierarchical cascade control engine (Mojo-native).

Local Wave transport; optional external Fala/Splot adapters are out of core.
Always-on local fusion fallback covers empty / weighted-mean / fail-closed paths.
"""

comptime TAKT_VERSION = "0.1.0"

from takt.types import (
    Wave,
    RawSignal,
    ErrorSignal,
    Actuation,
    SafetyInterlock,
    Telemetry,
    OutgoingSignals,
)
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.plant import TreeNode, MathTreePlant, make_numeric_tree, make_plant_dfs
from takt.fusion import SplotFusionUnit
from takt.regulator import CascadeRegulator
from takt.builder import LayerSpec, CascadeChain, build_cascade
from takt.sequencer import TaktResult, TaktSequencer
