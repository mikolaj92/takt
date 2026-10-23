"""CascadeRegulator.evaluate: within tolerance, actuation, interlock fail-closed."""

from std.collections import List
from std.math import abs
from takt.fusion import SplotFusionUnit
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.plant import TreeNode
from takt.regulator import CascadeRegulator
from takt.types import RawSignal


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt regulator evaluate smoke: " + msg)


def _approx(a: Float64, b: Float64, eps: Float64 = 1e-9) -> Bool:
    return abs(a - b) < eps


def main() raises:
    # Within tolerance → no actuation, no interlock
    var h_ok = ProfilHomeostatyczny(0)
    h_ok.add_variable(EssentialVariable("dev", 0.2, 0.01))
    var reg_ok = CascadeRegulator(0, h_ok)
    var r_ok = reg_ok.evaluate(TreeNode("node", 0.05))
    _check(r_ok.has_error, "within: has error")
    _check(abs(r_ok.error.aberration) < 0.2, "within: aberration small")
    _check(not r_ok.has_actuation, "within: no actuation")
    _check(not r_ok.has_interlock, "within: no interlock")
    _check(r_ok.error.reducer == "fallback", "within: local fallback reducer")

    # Outside tolerance with sufficient confidence → Actuation
    var h_act = ProfilHomeostatyczny(0, 0.35, 0.5)
    h_act.add_variable(EssentialVariable("dev", 0.1, 0.01))
    var reg_act = CascadeRegulator(0, h_act, SplotFusionUnit())
    var r_act = reg_act.evaluate(TreeNode("node", 0.8))
    _check(r_act.has_error, "act: has error")
    _check(_approx(r_act.error.aberration, 0.8), "act: aberration 0.8")
    _check(_approx(r_act.error.confidence, 0.8), "act: confidence 0.8")
    _check(_approx(r_act.error.residual_entropy, 0.3), "act: residual 0.3")
    _check(r_act.error.residual_entropy <= h_act.entropy_threshold, "act: residual ok")
    _check(r_act.has_actuation, "act: has actuation")
    _check(r_act.actuation.node_id == "node", "act: node id")
    _check(not r_act.has_interlock, "act: no interlock")
    _check(r_act.error.reducer == "fallback", "act: fallback reducer")

    # High residual / low confidence → SafetyInterlock, no Actuation
    var h_il = ProfilHomeostatyczny(0, 0.35, 0.6)
    h_il.add_variable(EssentialVariable("dev", 0.1, 0.01))
    var reg_il = CascadeRegulator(0, h_il)
    var low = List[RawSignal]()
    low.append(RawSignal("bad0", "node", "d0", 10.0, 0.2))
    low.append(RawSignal("bad1", "node", "d1", -10.0, 0.2))
    reg_il.inject_raw(low^)
    var r_il = reg_il.evaluate(TreeNode("node", 0.0))
    _check(r_il.has_error, "il: has error")
    _check(r_il.error.confidence < 0.6, "il: low confidence")
    _check(r_il.error.residual_entropy > 0.35, "il: high residual")
    _check(r_il.has_interlock, "il: has interlock")
    _check(not r_il.has_actuation, "il: no actuation (fail-closed)")
    _check(
        r_il.error.reducer == "fallback"
        or r_il.error.reducer == "fallback_conflict"
        or r_il.error.reducer == "fallback_disagreement",
        "il: local fallback* reducer",
    )

    print("takt regulator evaluate smoke ok")
