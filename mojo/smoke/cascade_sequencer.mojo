"""Multi-layer cascade + TaktSequencer: wiring, waves, multi-tact clock."""

from std.collections import List, Dict
from takt.builder import LayerSpec, build_cascade
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.plant import make_numeric_tree
from takt.sequencer import TaktSequencer
from takt.types import Wave


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt cascade sequencer smoke: " + msg)


def main() raises:
    # build_cascade wires parent/child indices and names
    var specs = List[LayerSpec]()
    specs.append(LayerSpec(0, ProfilHomeostatyczny(0)))
    specs.append(LayerSpec(1, ProfilHomeostatyczny(1)))
    var chain = build_cascade(specs^)
    _check(chain.layer_count() == 2, "two layers")
    _check(chain.root_index == 1, "root is highest layer")
    var root = chain.root()
    _check(root.layer == 1, "root.layer == 1")
    _check(root.name == "reg_L1", "root name")
    var child = chain.get_layer(0)
    _check(child.layer == 0, "child layer 0")
    _check(child.parent_name == "reg_L1", "child parent_name")
    _check(chain.child_of(1) == 0, "child_of root")
    _check(chain.parent_of(0) == 1, "parent_of child")

    # Sequential scan order via sequencer clock
    var values = List[Float64]()
    values.append(0.1)
    values.append(0.5)
    values.append(-0.3)
    var plant = make_numeric_tree(values^)

    var h0 = ProfilHomeostatyczny(0)
    h0.add_variable(EssentialVariable("dev", 10.0))
    var h1 = ProfilHomeostatyczny(1)
    h1.add_variable(EssentialVariable("dev", 0.05))
    var layers = List[LayerSpec]()
    layers.append(LayerSpec(0, h0))
    layers.append(LayerSpec(1, h1))
    var cascade = build_cascade(layers^)
    var seq = TaktSequencer(plant, cascade)

    var constraints = Dict[String, Float64]()
    constraints["dev"] = 0.01
    var top = Wave("w1", 1, "L1", "", constraints^)

    var root_result = seq.run_one_tact(True, top)
    _check(root_result.tact == 0, "first tact index 0")
    _check(root_result.node_id == "root", "first node root")
    # two layers → telemetry from both (root has children)
    _check(len(root_result.signals.telemetry) == 2, "two-layer telemetry count")

    var n0 = seq.run_one_tact(True, top)
    _check(n0.tact == 1, "second tact index 1")
    _check(n0.node_id == "n0", "second node n0")
    _check(n0.signals.has_error, "n0 has error")
    _check(
        n0.signals.has_actuation or n0.signals.has_interlock,
        "n0 actuation or interlock",
    )

    # Multi-step run advances tact index
    var values2 = List[Float64]()
    values2.append(0.3)
    var plant2 = make_numeric_tree(values2^)
    var h_simple = ProfilHomeostatyczny(0)
    h_simple.add_variable(EssentialVariable("dev", 0.1))
    var one = List[LayerSpec]()
    one.append(LayerSpec(0, h_simple))
    var chain1 = build_cascade(one^)
    var seq2 = TaktSequencer(plant2, chain1)
    var multi = seq2.run(3)
    _check(len(multi) == 3, "run returns 3 results")
    _check(multi[0].tact == 0, "step0 tact 0")
    _check(multi[1].tact == 1, "step1 tact 1")
    _check(multi[2].tact == 2, "step2 tact 2")
    # plant has root + n0 → wraps: 0=root, 1=n0, 2=root
    _check(multi[0].node_id == "root", "step0 root")
    _check(multi[1].node_id == "n0", "step1 n0")
    _check(multi[2].node_id == "root", "step2 wrap root")

    # Within-tolerance single layer via sequencer
    var h_tol = ProfilHomeostatyczny(0)
    h_tol.add_variable(EssentialVariable("dev", 0.2, 0.01))
    var tol_layers = List[LayerSpec]()
    tol_layers.append(LayerSpec(0, h_tol))
    var vals_tol = List[Float64]()
    vals_tol.append(0.05)
    var seq_tol = TaktSequencer(make_numeric_tree(vals_tol^), build_cascade(tol_layers^))
    var r_tol = seq_tol.run_one_tact()  # root
    _check(not r_tol.signals.has_actuation, "tol: no act on root")
    _check(not r_tol.signals.has_interlock, "tol: no il on root")

    # Outside tolerance leaf → actuation
    var h_out = ProfilHomeostatyczny(0, 0.35, 0.5)
    h_out.add_variable(EssentialVariable("dev", 0.1, 0.01))
    var out_layers = List[LayerSpec]()
    out_layers.append(LayerSpec(0, h_out))
    var vals_out = List[Float64]()
    vals_out.append(0.8)
    var seq_out = TaktSequencer(make_numeric_tree(vals_out^), build_cascade(out_layers^))
    _ = seq_out.run_one_tact()  # root
    var r_out = seq_out.run_one_tact()  # n0
    _check(r_out.node_id == "n0", "out: n0")
    _check(r_out.signals.has_actuation, "out: actuation")
    _check(not r_out.signals.has_interlock, "out: no interlock")

    print("takt cascade sequencer smoke ok")
