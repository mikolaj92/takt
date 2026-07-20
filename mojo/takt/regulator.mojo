"""CascadeRegulator — one control loop in an n-layer hierarchy."""

from std.collections import List, Dict
from std.math import abs
from takt.fusion import SplotFusionUnit
from takt.homeostat import ProfilHomeostatyczny
from takt.plant import TreeNode
from takt.types import (
    Actuation,
    OutgoingSignals,
    RawSignal,
    SafetyInterlock,
    Telemetry,
    Wave,
)


struct CascadeRegulator(Copyable, Movable):
    """Single cascade layer: collect → fuse → fail-closed act/interlock."""

    var layer: Int
    var homeostat: ProfilHomeostatyczny
    var fusion: SplotFusionUnit
    var name: String
    var parent_name: String
    var seq: Int
    var extra_raw: List[RawSignal]

    def __init__(
        out self,
        layer: Int,
        homeostat: ProfilHomeostatyczny,
        fusion: SplotFusionUnit = SplotFusionUnit(),
        name: String = "",
        parent_name: String = "",
    ):
        self.layer = layer
        self.homeostat = homeostat.copy()
        self.fusion = fusion.copy()
        if name.byte_length() == 0:
            self.name = "reg_L" + String(layer)
        else:
            self.name = name
        self.parent_name = parent_name
        self.seq = 0
        self.extra_raw = List[RawSignal]()

    def __init__(out self, *, copy: Self):
        self.layer = copy.layer
        self.homeostat = copy.homeostat.copy()
        self.fusion = copy.fusion.copy()
        self.name = copy.name
        self.parent_name = copy.parent_name
        self.seq = copy.seq
        self.extra_raw = copy.extra_raw.copy()

    def _next_id(mut self, prefix: String) -> String:
        self.seq += 1
        return prefix + "_" + String(self.seq)

    def inject_raw(mut self, signals: List[RawSignal]):
        """Inject raw signals for the next evaluate (test / host detectors)."""
        self.extra_raw = signals.copy()

    def clear_extra_raw(mut self):
        self.extra_raw = List[RawSignal]()

    def _collect_raw_signals(
        mut self, node: TreeNode, has_incoming: Bool, incoming: Wave
    ) -> List[RawSignal]:
        var signals = List[RawSignal]()

        # 1. Descending wave constraints → raw signals
        if has_incoming:
            for entry in incoming.constraints.items():
                var key = entry.key
                var val = entry.value
                signals.append(
                    RawSignal(
                        "wave:" + incoming.wave_id + ":" + key,
                        node.id,
                        "parent_wave",
                        val,
                        0.95,
                    )
                )

        # 2. Injected / detector raw signals
        for i in range(len(self.extra_raw)):
            signals.append(self.extra_raw[i].copy())
        self.extra_raw = List[RawSignal]()

        # 3. Intrinsic numeric node value as deviation
        if abs(node.value) > 1e-12:
            signals.append(
                RawSignal(
                    "node_value:" + node.id,
                    node.id,
                    "intrinsic_value",
                    node.value,
                    0.8,
                )
            )

        return signals^

    def evaluate(
        mut self, node: TreeNode, has_incoming: Bool = False, incoming: Wave = Wave(
            "none", 0, ""
        )
    ) -> OutgoingSignals:
        """One tact evaluation at this layer.

        1. Collect raw (wave + injected + node value)
        2. Fuse → ErrorSignal
        3. Homeostat → Actuation / Interlock / stable
        4. Ascending wave + telemetry
        """
        var raw = self._collect_raw_signals(node, has_incoming, incoming)
        var error = self.fusion.fuse(raw, node.id)

        var out = OutgoingSignals()
        out.has_error = True
        out.error = error.copy()

        var tel = List[Telemetry]()

        if self.homeostat.should_interlock(error.residual_entropy, error.confidence):
            var blocked = error.contributing_signals.copy()
            var interlock = SafetyInterlock(
                self._next_id("il"),
                node.id,
                "high_residual_entropy_or_low_confidence",
                error.residual_entropy,
                blocked^,
            )
            out.has_interlock = True
            out.interlock = interlock.copy()
            tel.append(
                Telemetry(self._next_id("tel"), node.id, self.layer, "interlock")
            )
        else:
            var should_act: Bool
            if self.homeostat.variable_count() == 0:
                should_act = (
                    abs(error.aberration) > 1e-9
                    and error.confidence >= self.homeostat.min_confidence
                )
            else:
                should_act = self.homeostat.any_tolerance_exceeded(error.aberration)

            if should_act:
                var actuation = Actuation(
                    self._next_id("act"),
                    node.id,
                    "correct_aberration",
                    -error.aberration,
                    error.aberration,
                )
                out.has_actuation = True
                out.actuation = actuation.copy()

        var constraints = Dict[String, Float64]()
        constraints["aberration"] = error.aberration
        constraints["confidence"] = error.confidence
        var ascending = Wave(
            self._next_id("asc"),
            self.layer,
            node.id,
            self.parent_name,
            constraints^,
            node.id,
            self.layer,
            out.has_interlock,
            error.residual_entropy,
        )
        out.has_ascending_wave = True
        out.ascending_wave = ascending.copy()

        tel.append(Telemetry(self._next_id("tel"), node.id, self.layer, "evaluation"))
        out.telemetry = tel^
        return out^
