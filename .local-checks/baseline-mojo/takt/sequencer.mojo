"""TaktSequencer — discrete clock: one plant node = one tact."""

from std.collections import List, Dict
from takt.builder import CascadeChain
from takt.plant import MathTreePlant, TreeNode
from takt.types import OutgoingSignals, Telemetry, Wave


struct TaktResult(Copyable, Movable):
    """Result of one tact evaluation."""

    var tact: Int
    var node_id: String
    var node_value: Float64
    var signals: OutgoingSignals
    var has_descending_wave: Bool
    var descending_wave: Wave

    def __init__(
        out self,
        tact: Int,
        node_id: String,
        node_value: Float64,
        signals: OutgoingSignals,
        has_descending_wave: Bool = False,
        descending_wave: Wave = Wave("none", 0, ""),
    ):
        self.tact = tact
        self.node_id = node_id
        self.node_value = node_value
        self.signals = signals.copy()
        self.has_descending_wave = has_descending_wave
        self.descending_wave = descending_wave.copy()

    def __init__(out self, *, copy: Self):
        self.tact = copy.tact
        self.node_id = copy.node_id
        self.node_value = copy.node_value
        self.signals = copy.signals.copy()
        self.has_descending_wave = copy.has_descending_wave
        self.descending_wave = copy.descending_wave.copy()


struct TaktSequencer(Copyable, Movable):
    """Drives cascade regulators over plant sequential_scan order."""

    var plant: MathTreePlant
    var chain: CascadeChain
    var tact: Int
    var desc_seq: Int

    def __init__(out self, plant: MathTreePlant, chain: CascadeChain):
        self.plant = plant.copy()
        self.chain = chain.copy()
        self.tact = 0
        self.desc_seq = 0

    def __init__(out self, *, copy: Self):
        self.plant = copy.plant.copy()
        self.chain = copy.chain.copy()
        self.tact = copy.tact
        self.desc_seq = copy.desc_seq

    def current_tact(self) -> Int:
        return self.tact

    def reset(mut self):
        self.tact = 0

    def run_one_tact(
        mut self, has_top_wave: Bool = False, top_wave: Wave = Wave("none", 0, "")
    ) raises -> TaktResult:
        """Take next node, evaluate cascade from root downward."""
        var nodes = self.plant.sequential_scan()
        if len(nodes) == 0:
            raise Error("Plant returned empty scan — no nodes")

        var idx = self.tact % len(nodes)
        var node = nodes[idx].copy()
        var result = self._evaluate_cascade(node, has_top_wave, top_wave)
        self.tact += 1
        return result^

    def _evaluate_cascade(
        mut self, node: TreeNode, has_incoming: Bool, incoming: Wave
    ) raises -> TaktResult:
        """Evaluate from highest layer down; merge child outcomes fail-closed."""
        if self.chain.root_index < 0:
            raise Error("cascade has no root")

        var root_i = self.chain.root_index
        var root_reg = self.chain.layers[root_i].copy()
        var out = root_reg.evaluate(node, has_incoming, incoming)
        self.chain.layers[root_i] = root_reg^

        var descending = Wave("none", 0, "")
        var has_desc = False
        if out.has_ascending_wave:
            descending = out.ascending_wave.copy()
            has_desc = True

        var parent_out = out.copy()
        var i = root_i
        while i > 0 and node.has_children():
            var child_i = i - 1
            self.desc_seq += 1
            var child_constraints = Dict[String, Float64]()
            if parent_out.has_ascending_wave:
                for entry in parent_out.ascending_wave.constraints.items():
                    child_constraints[entry.key] = entry.value

            var child_wave = Wave(
                "desc_" + String(self.desc_seq),
                self.chain.layers[child_i].layer,
                self.chain.layers[i].name,
                "",
                child_constraints^,
                node.id,
                self.chain.layers[i].layer,
                False,
                0.0,
            )

            var child_reg = self.chain.layers[child_i].copy()
            var child_out = child_reg.evaluate(node, True, child_wave)
            self.chain.layers[child_i] = child_reg^

            var merged = OutgoingSignals()
            merged.has_error = parent_out.has_error
            if parent_out.has_error:
                merged.error = parent_out.error.copy()

            if child_out.has_interlock:
                merged.has_interlock = True
                merged.interlock = child_out.interlock.copy()
            elif parent_out.has_interlock:
                merged.has_interlock = True
                merged.interlock = parent_out.interlock.copy()

            if not merged.has_interlock:
                if child_out.has_actuation:
                    merged.has_actuation = True
                    merged.actuation = child_out.actuation.copy()
                elif parent_out.has_actuation:
                    merged.has_actuation = True
                    merged.actuation = parent_out.actuation.copy()

            var mt = List[Telemetry]()
            for t in range(len(parent_out.telemetry)):
                mt.append(parent_out.telemetry[t].copy())
            for t in range(len(child_out.telemetry)):
                mt.append(child_out.telemetry[t].copy())
            merged.telemetry = mt^

            if child_out.has_ascending_wave:
                merged.has_ascending_wave = True
                merged.ascending_wave = child_out.ascending_wave.copy()
            elif parent_out.has_ascending_wave:
                merged.has_ascending_wave = True
                merged.ascending_wave = parent_out.ascending_wave.copy()

            parent_out = merged^
            i = child_i

        return TaktResult(
            self.tact,
            node.id,
            node.value,
            parent_out^,
            has_desc,
            descending,
        )

    def run(
        mut self,
        steps: Int,
        has_initial: Bool = False,
        initial_wave: Wave = Wave("none", 0, ""),
    ) raises -> List[TaktResult]:
        """Run N tacts; ascending wave of prior step becomes next context."""
        var results = List[TaktResult]()
        var has_wave = has_initial
        var wave = initial_wave.copy()
        for _ in range(steps):
            var r = self.run_one_tact(has_wave, wave)
            if r.signals.has_ascending_wave:
                has_wave = True
                wave = r.signals.ascending_wave.copy()
            results.append(r^)
        return results^
