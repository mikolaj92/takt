"""Helpers for multi-layer cascade wiring."""

from std.collections import List
from takt.fusion import SplotFusionUnit
from takt.homeostat import ProfilHomeostatyczny
from takt.regulator import CascadeRegulator


struct LayerSpec(Copyable, Movable):
    """One layer entry for build_cascade: (layer index, homeostat)."""

    var layer: Int
    var homeostat: ProfilHomeostatyczny

    def __init__(out self, layer: Int, homeostat: ProfilHomeostatyczny):
        self.layer = layer
        self.homeostat = homeostat.copy()

    def __init__(out self, *, copy: Self):
        self.layer = copy.layer
        self.homeostat = copy.homeostat.copy()


struct CascadeChain(Copyable, Movable):
    """Wired multi-layer cascade: layers ordered L0 .. L{n-1}, root = highest."""

    var layers: List[CascadeRegulator]
    var root_index: Int

    def __init__(out self):
        self.layers = List[CascadeRegulator]()
        self.root_index = -1

    def __init__(out self, *, copy: Self):
        self.layers = copy.layers.copy()
        self.root_index = copy.root_index

    def root(mut self) raises -> CascadeRegulator:
        if self.root_index < 0 or self.root_index >= len(self.layers):
            raise Error("cascade has no root")
        return self.layers[self.root_index].copy()

    def layer_count(self) -> Int:
        return len(self.layers)

    def get_layer(self, i: Int) raises -> CascadeRegulator:
        return self.layers[i].copy()

    def child_of(self, i: Int) -> Int:
        """Index of child (lower) layer, or -1 if none."""
        if i <= 0:
            return -1
        return i - 1

    def parent_of(self, i: Int) -> Int:
        """Index of parent (higher) layer, or -1 if root."""
        if i < 0 or i >= len(self.layers) - 1:
            return -1
        return i + 1


def build_cascade(specs: List[LayerSpec]) raises -> CascadeChain:
    """Build L0..Ln-1 chain. specs sorted ascending by layer. Returns root-ready chain.

    Bidirectional links are encoded as parent_name on lower layers and
    layer indices (child = i-1, parent = i+1) on the chain.
    """
    if len(specs) == 0:
        raise Error("build_cascade requires at least one layer")

    var chain = CascadeChain()
    for i in range(len(specs)):
        var spec = specs[i].copy()
        var parent_name = String("")
        if i + 1 < len(specs):
            parent_name = "reg_L" + String(specs[i + 1].layer)
        var reg = CascadeRegulator(
            spec.layer,
            spec.homeostat,
            SplotFusionUnit(),
            "reg_L" + String(spec.layer),
            parent_name,
        )
        chain.layers.append(reg^)

    chain.root_index = len(chain.layers) - 1
    return chain^
