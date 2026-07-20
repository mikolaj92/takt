"""Local fusion unit: weighted-mean fallback (splot optional, not required)."""

from std.collections import List
from std.math import max
from takt.types import ErrorSignal, RawSignal


struct SplotFusionUnit(Copyable, Movable):
    """Decision processor: always-on local fallback reducer.

    Empty raw list → zero aberration / high confidence.
    Non-empty → weighted-mean aberration, min confidence, residual entropy.
    Optional splot path is intentionally not wired here so core smokes never
    depend on a sibling Splot checkout.
    """

    var seq: Int
    var force_fallback: Bool

    def __init__(out self, force_fallback: Bool = True):
        self.seq = 0
        self.force_fallback = force_fallback

    def __init__(out self, *, copy: Self):
        self.seq = copy.seq
        self.force_fallback = copy.force_fallback

    def _next_id(mut self, prefix: String) -> String:
        self.seq += 1
        return prefix + "_" + String(self.seq)

    def fuse(mut self, raw_signals: List[RawSignal], node_id: String) -> ErrorSignal:
        if len(raw_signals) == 0:
            return ErrorSignal(
                self._next_id("err"),
                node_id,
                0.0,
                1.0,
                0.0,
                List[String](),
                "empty",
                0,
            )
        return self._fuse_fallback(raw_signals, node_id)

    def _fuse_fallback(
        mut self, raw_signals: List[RawSignal], node_id: String
    ) -> ErrorSignal:
        var total_weight: Float64 = 0.0
        var weighted_sum: Float64 = 0.0
        var min_conf: Float64 = 1.0
        var ids = List[String]()

        for i in range(len(raw_signals)):
            var sig = raw_signals[i].copy()
            var w: Float64 = 1.0
            weighted_sum += sig.deviation * w
            total_weight += w
            if sig.confidence < min_conf:
                min_conf = sig.confidence
            ids.append(sig.signal_id)

        var aberration: Float64 = 0.0
        if total_weight > 0.0:
            aberration = weighted_sum / total_weight
        var confidence = min_conf
        var residual = max(0.3, 1.0 - confidence)

        return ErrorSignal(
            self._next_id("err"),
            node_id,
            aberration,
            confidence,
            residual,
            ids^,
            "fallback",
            len(raw_signals),
        )
