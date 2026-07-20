"""Local fusion fallback: empty / single / multi raw signals."""

from std.collections import List
from std.math import abs
from takt.fusion import SplotFusionUnit
from takt.types import RawSignal


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt fusion fallback smoke: " + msg)


def _approx(a: Float64, b: Float64, eps: Float64 = 1e-9) -> Bool:
    return abs(a - b) < eps


def main() raises:
    var fusion = SplotFusionUnit()

    # Empty → zero aberration, high confidence, residual 0, reducer empty
    var empty = List[RawSignal]()
    var e0 = fusion.fuse(empty, "node")
    _check(e0.aberration == 0.0, "empty aberration 0")
    _check(e0.confidence == 1.0, "empty confidence 1")
    _check(e0.residual_entropy == 0.0, "empty residual 0")
    _check(e0.reducer == "empty", "empty reducer")
    _check(len(e0.contributing_signals) == 0, "empty contributing")

    # Single signal
    var one = List[RawSignal]()
    one.append(RawSignal("s0", "node", "d0", 0.8, 0.8))
    var e1 = fusion.fuse(one, "node")
    _check(e1.reducer == "fallback", "single reducer fallback")
    _check(_approx(e1.aberration, 0.8), "single aberration")
    _check(_approx(e1.confidence, 0.8), "single confidence")
    _check(_approx(e1.residual_entropy, 0.3), "single residual max(0.3, 1-c)")
    _check(e1.raw_count == 1, "single raw_count")
    _check(len(e1.contributing_signals) == 1, "single contributing")

    # Multi: weighted mean of deviations, min confidence
    var multi = List[RawSignal]()
    multi.append(RawSignal("s0", "node", "d0", 0.8, 0.9))
    multi.append(RawSignal("s1", "node", "d1", 0.4, 0.7))
    var e2 = fusion.fuse(multi, "node")
    _check(e2.reducer == "fallback", "multi reducer")
    _check(_approx(e2.aberration, 0.6), "multi mean (0.8+0.4)/2")
    _check(_approx(e2.confidence, 0.7), "multi min confidence")
    # residual = max(0.3, 1-0.7) = 0.3
    _check(_approx(e2.residual_entropy, 0.3), "multi residual")
    _check(e2.raw_count == 2, "multi raw_count")

    print("takt fusion fallback smoke ok")
