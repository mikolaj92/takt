"""Local fusion unit: weighted mean + disagreement residual (no splot required).

Empty raw list → zero aberration / high confidence / residual 0.
Non-empty → weighted-mean aberration, confidence from min raw confidence
(further reduced when signals disagree), residual entropy from uncertainty
and spread. Optional external splot is host-side; core never imports it.
"""

from std.collections import List
from std.math import abs, max, sqrt
from takt.types import ErrorSignal, RawSignal


struct SplotFusionUnit(Copyable, Movable):
    """Always-on local reducer for cascade evaluate."""

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
        var n = len(raw_signals)

        for i in range(n):
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

        # Population std-dev of deviations → disagreement in [0, 1]
        var variance: Float64 = 0.0
        if n > 0:
            for i in range(n):
                var d = raw_signals[i].deviation - aberration
                variance += d * d
            variance = variance / Float64(n)
        var spread = sqrt(variance)
        var scale = abs(aberration) + 1.0
        var disagree = spread / scale
        if disagree > 1.0:
            disagree = 1.0

        # Opposing signs among non-near-zero deviations → hard conflict
        var saw_pos = False
        var saw_neg = False
        for i in range(n):
            var d = raw_signals[i].deviation
            if d > 1e-9:
                saw_pos = True
            if d < -1e-9:
                saw_neg = True
        var conflict = saw_pos and saw_neg

        var confidence = min_conf
        if conflict:
            # Fail closed: contradictory detectors collapse confidence
            confidence = min_conf * 0.25
            if confidence > 0.15:
                confidence = 0.15
        elif disagree > 0.25:
            confidence = min_conf * (1.0 - 0.5 * disagree)

        # Residual: at least 0.3 when any signal present; rises with uncertainty
        # and disagreement (strict fail-closed friendly).
        var residual = max(0.3, 1.0 - confidence)
        residual = max(residual, disagree)
        if conflict:
            residual = max(residual, 0.85)

        var reducer = "fallback"
        if conflict:
            reducer = "fallback_conflict"
        elif disagree > 0.25:
            reducer = "fallback_disagreement"

        return ErrorSignal(
            self._next_id("err"),
            node_id,
            aberration,
            confidence,
            residual,
            ids^,
            reducer,
            n,
        )
