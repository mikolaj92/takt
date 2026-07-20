"""Full takt cascade smoke — ships all core behaviors via real APIs."""

from std.collections import List, Dict
from std.math import abs
from takt.builder import LayerSpec, build_cascade
from takt.fusion import SplotFusionUnit
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.plant import TreeNode, make_numeric_tree
from takt.regulator import CascadeRegulator
from takt.sequencer import TaktSequencer
from takt.types import RawSignal, Wave


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt full smoke: " + msg)


def _approx(a: Float64, b: Float64, eps: Float64 = 1e-9) -> Bool:
    return abs(a - b) < eps


def main() raises:
    # --- Plant scan order ---
    var values = List[Float64]()
    values.append(0.1)
    values.append(0.5)
    values.append(-0.3)
    var plant = make_numeric_tree(values^)
    var scan = plant.sequential_scan()
    _check(
        scan[0].id == "root"
        and scan[1].id == "n0"
        and scan[2].id == "n1"
        and scan[3].id == "n2",
        "scan order root then leaves",
    )

    # --- Fusion empty / fallback ---
    var fusion = SplotFusionUnit()
    var empty_err = fusion.fuse(List[RawSignal](), "x")
    _check(empty_err.reducer == "empty" and empty_err.aberration == 0.0, "empty fuse")
    var one = List[RawSignal]()
    one.append(RawSignal("s", "x", "d", 0.8, 0.8))
    var one_err = fusion.fuse(one, "x")
    _check(one_err.reducer == "fallback" and _approx(one_err.aberration, 0.8), "fallback fuse")

    # --- Within tolerance ---
    var h_ok = ProfilHomeostatyczny(0)
    h_ok.add_variable(EssentialVariable("dev", 0.2, 0.01))
    var reg_ok = CascadeRegulator(0, h_ok)
    var r_ok = reg_ok.evaluate(TreeNode("n", 0.05))
    _check(not r_ok.has_actuation and not r_ok.has_interlock, "within tolerance stable")

    # --- Outside tolerance → Actuation ---
    var h_act = ProfilHomeostatyczny(0, 0.35, 0.5)
    h_act.add_variable(EssentialVariable("dev", 0.1, 0.01))
    var reg_act = CascadeRegulator(0, h_act)
    var r_act = reg_act.evaluate(TreeNode("n", 0.8))
    _check(r_act.has_actuation and not r_act.has_interlock, "actuation path")
    _check(r_act.error.reducer == "fallback", "local reducer marked")

    # --- Low confidence → Interlock (fail-closed) ---
    var h_il = ProfilHomeostatyczny(0)
    h_il.add_variable(EssentialVariable("dev", 0.1))
    var reg_il = CascadeRegulator(0, h_il)
    var bad = List[RawSignal]()
    bad.append(RawSignal("a", "n", "d", 5.0, 0.1))
    reg_il.inject_raw(bad^)
    var r_il = reg_il.evaluate(TreeNode("n", 0.0))
    _check(r_il.has_interlock and not r_il.has_actuation, "interlock fail-closed")

    # --- Multi-layer cascade + top wave + multi-tact ---
    var h0 = ProfilHomeostatyczny(0)
    h0.add_variable(EssentialVariable("dev", 10.0))
    var h1 = ProfilHomeostatyczny(1)
    h1.add_variable(EssentialVariable("dev", 0.05))
    var specs = List[LayerSpec]()
    specs.append(LayerSpec(0, h0))
    specs.append(LayerSpec(1, h1))
    var chain = build_cascade(specs^)
    _check(chain.root().layer == 1, "cascade root layer")
    _check(chain.get_layer(0).parent_name == "reg_L1", "parent/child link")

    var vals = List[Float64]()
    vals.append(0.3)
    var seq = TaktSequencer(make_numeric_tree(vals^), chain)
    var cdict = Dict[String, Float64]()
    cdict["dev"] = 0.01
    var top = Wave("top", 1, "L1", "", cdict^)
    var root_r = seq.run_one_tact(True, top)
    _check(root_r.node_id == "root", "tact0 root")
    _check(len(root_r.signals.telemetry) == 2, "two-layer telemetry")
    var leaf_r = seq.run_one_tact(True, top)
    _check(leaf_r.node_id == "n0", "tact1 leaf")
    _check(leaf_r.signals.has_error, "leaf error present")

    var multi = seq.run(2)
    _check(len(multi) == 2, "multi-step length")
    _check(multi[0].tact == 2 and multi[1].tact == 3, "advancing tact index")

    print("takt cascade smoke ok")
    print("takt full smoke ok")
