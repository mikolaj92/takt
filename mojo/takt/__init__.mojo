"""takt: generic hierarchical cascade control engine (Mojo engine).

Local Wave transport; optional external Fala/Splot adapters are host-side.
Always-on local fusion covers empty / weighted-mean / disagreement / fail-closed.
Optional Python binding is `python/takt` over this same engine.
"""

comptime TAKT_VERSION = "0.3.1"

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
from takt.plant import (
    TreeNode,
    MathTreePlant,
    make_numeric_tree,
    make_plant_dfs,
    make_layered_plant,
    make_document_plant,
    make_code_plant,
)
from takt.fusion import SplotFusionUnit
from takt.regulator import CascadeRegulator
from takt.builder import LayerSpec, CascadeChain, build_cascade
from takt.sequencer import TaktResult, TaktSequencer
from takt.adapters_fala import cascade_step, run_stdio_line
