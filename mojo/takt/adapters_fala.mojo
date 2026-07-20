"""Fala / process-host boundary: JSON in → one cascade step out.

Takt does not import Fala. The host owns scheduling, plant construction from
domain sources, and persistence. This adapter only runs cascade evaluate / run
from a host-supplied request JSON and returns a thin result envelope.
"""

from std.collections import List, Dict
from takt.builder import LayerSpec, build_cascade
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.json_lite import (
    extract_object_array,
    has_key,
    quote,
    read_bool_field,
    read_float_field,
    read_int_field,
    read_string_field,
)
from takt.plant import MathTreePlant, TreeNode, make_layered_plant
from takt.sequencer import TaktSequencer
from takt.types import RawSignal, Wave


def _signals_to_json(
    has_error: Bool,
    aberration: Float64,
    confidence: Float64,
    residual: Float64,
    reducer: String,
    has_actuation: Bool,
    actuation_node: String,
    has_interlock: Bool,
    interlock_reason: String,
    telemetry_count: Int,
) -> String:
    var act = "null"
    if has_actuation:
        act = (
            "{\"node_id\":"
            + quote(actuation_node)
            + ",\"command\":\"correct_aberration\"}"
        )
    var il = "null"
    if has_interlock:
        il = (
            "{\"reason\":"
            + quote(interlock_reason)
            + ",\"residual_entropy\":"
            + String(residual)
            + "}"
        )
    var err = "null"
    if has_error:
        err = (
            "{\"aberration\":"
            + String(aberration)
            + ",\"confidence\":"
            + String(confidence)
            + ",\"residual_entropy\":"
            + String(residual)
            + ",\"reducer\":"
            + quote(reducer)
            + "}"
        )
    return (
        "{\"error\":"
        + err
        + ",\"actuation\":"
        + act
        + ",\"interlock\":"
        + il
        + ",\"telemetry_count\":"
        + String(telemetry_count)
        + "}"
    )


def _parse_layers(text: String) raises -> List[LayerSpec]:
    var specs = List[LayerSpec]()
    var objs = extract_object_array(text, "layers")
    if len(objs) == 0:
        var h = ProfilHomeostatyczny(0)
        h.add_variable(
            EssentialVariable(
                "dev",
                read_float_field(text, "tolerance", 0.1),
                0.01,
            )
        )
        h.min_confidence = read_float_field(text, "min_confidence", 0.6)
        h.entropy_threshold = read_float_field(text, "entropy_threshold", 0.35)
        specs.append(LayerSpec(0, h))
        return specs^

    for i in range(len(objs)):
        var o = objs[i]
        var layer = read_int_field(o, "layer", i)
        var h = ProfilHomeostatyczny(
            layer,
            read_float_field(o, "entropy_threshold", 0.35),
            read_float_field(o, "min_confidence", 0.6),
        )
        h.add_variable(
            EssentialVariable(
                "dev",
                read_float_field(o, "tolerance", 0.1),
                read_float_field(o, "cutoff", 0.01),
            )
        )
        specs.append(LayerSpec(layer, h))
    return specs^


def _parse_plant(text: String) raises -> MathTreePlant:
    var objs = extract_object_array(text, "plant_nodes")
    if len(objs) == 0:
        var nid = read_string_field(text, "node_id", "node")
        var nval = read_float_field(text, "node_value", 0.0)
        if has_key(text, "id"):
            nid = read_string_field(text, "id", nid)
        if has_key(text, "value"):
            nval = read_float_field(text, "value", nval)
        var nodes = List[TreeNode]()
        nodes.append(TreeNode(nid, nval, False, "", 0, "node"))
        return make_layered_plant(nodes^)

    var nodes = List[TreeNode]()
    for i in range(len(objs)):
        var o = objs[i]
        nodes.append(
            TreeNode(
                read_string_field(o, "id", "n" + String(i)),
                read_float_field(o, "value", 0.0),
                read_bool_field(o, "has_children", False),
                read_string_field(o, "parent_id", ""),
                read_int_field(o, "layer", 0),
                read_string_field(o, "kind", "node"),
            )
        )
    return make_layered_plant(nodes^)


def _parse_raw(text: String, node_id: String) raises -> List[RawSignal]:
    var out = List[RawSignal]()
    var objs = extract_object_array(text, "raw_signals")
    for i in range(len(objs)):
        var o = objs[i]
        out.append(
            RawSignal(
                read_string_field(o, "signal_id", "s" + String(i)),
                read_string_field(o, "node_id", node_id),
                read_string_field(o, "detector", "host"),
                read_float_field(o, "deviation", 0.0),
                read_float_field(o, "confidence", 1.0),
            )
        )
    return out^


def _parse_constraints(text: String) raises -> Dict[String, Float64]:
    var c = Dict[String, Float64]()
    if has_key(text, "constraint_dev"):
        c["dev"] = read_float_field(text, "constraint_dev", 0.0)
    if has_key(text, "incoming_constraints"):
        # fixtures: "incoming_constraints":{"dev":0.01,"policy":...}
        if text.find("\"dev\"") >= 0:
            c["dev"] = read_float_field(text, "dev", 0.0)
        if text.find("\"policy\"") >= 0:
            c["policy"] = read_float_field(text, "policy", 0.0)
    return c^


def cascade_step(input_json: String) raises -> String:
    """One cascade evaluation or multi-tact run from host JSON.

    Modes:
      - evaluate (default): one tact on plant (root first)
      - run: TaktSequencer.run(steps) over plant_nodes
    """
    var mode = read_string_field(input_json, "mode", "evaluate")
    var now = read_string_field(input_json, "now", "2026-01-01T00:00:00Z")
    var specs = _parse_layers(input_json)
    var chain = build_cascade(specs^)
    var plant = _parse_plant(input_json)
    var constraints = _parse_constraints(input_json)
    var has_wave = len(constraints) > 0
    var top_layer = chain.root().layer
    var wave = Wave("host_top", top_layer, "host", "", constraints.copy())

    if mode == "run":
        var steps = read_int_field(input_json, "steps", plant.node_count())
        var seq = TaktSequencer(plant, chain)
        var results = seq.run(steps, has_wave, wave)
        var items = String("[")
        for i in range(len(results)):
            if i > 0:
                items += ","
            var r = results[i].copy()
            var sig = r.signals.copy()
            var ab: Float64 = 0.0
            var conf: Float64 = 1.0
            var res: Float64 = 0.0
            var red = String("none")
            if sig.has_error:
                ab = sig.error.aberration
                conf = sig.error.confidence
                res = sig.error.residual_entropy
                red = sig.error.reducer
            var anode = String("")
            if sig.has_actuation:
                anode = sig.actuation.node_id
            var ireason = String("")
            if sig.has_interlock:
                ireason = sig.interlock.reason
            items += (
                "{\"tact\":"
                + String(r.tact)
                + ",\"node_id\":"
                + quote(r.node_id)
                + ",\"node_value\":"
                + String(r.node_value)
                + ",\"signals\":"
                + _signals_to_json(
                    sig.has_error,
                    ab,
                    conf,
                    res,
                    red,
                    sig.has_actuation,
                    anode,
                    sig.has_interlock,
                    ireason,
                    len(sig.telemetry),
                )
                + "}"
            )
        items += "]"
        return (
            "{\"ok\":true,\"mode\":\"run\",\"now\":"
            + quote(now)
            + ",\"steps\":"
            + String(len(results))
            + ",\"results\":"
            + items
            + ",\"events\":[{\"type\":\"takt.cascade_run\",\"steps\":"
            + String(len(results))
            + "}]}"
        )

    # evaluate: inject optional raw_signals on L0, then one tact
    var nodes = plant.sequential_scan()
    var node = nodes[0].copy()
    var raw = _parse_raw(input_json, node.id)
    if len(raw) > 0:
        # Inject on every layer so single-node multi-layer still sees detectors.
        for li in range(len(chain.layers)):
            var reg_i = chain.layers[li].copy()
            reg_i.inject_raw(raw.copy())
            chain.layers[li] = reg_i^

    var seq_e = TaktSequencer(plant, chain)
    var result = seq_e.run_one_tact(has_wave, wave)
    var sig = result.signals.copy()
    var outcome = "stable"
    if sig.has_interlock:
        outcome = "interlock"
    elif sig.has_actuation:
        outcome = "actuation"

    var ab2: Float64 = 0.0
    var conf2: Float64 = 1.0
    var res2: Float64 = 0.0
    var red2 = String("none")
    if sig.has_error:
        ab2 = sig.error.aberration
        conf2 = sig.error.confidence
        res2 = sig.error.residual_entropy
        red2 = sig.error.reducer
    var anode2 = String("")
    if sig.has_actuation:
        anode2 = sig.actuation.node_id
    var ireason2 = String("")
    if sig.has_interlock:
        ireason2 = sig.interlock.reason

    return (
        "{\"ok\":true,\"mode\":\"evaluate\",\"now\":"
        + quote(now)
        + ",\"tact\":"
        + String(result.tact)
        + ",\"node_id\":"
        + quote(result.node_id)
        + ",\"outcome\":"
        + quote(outcome)
        + ",\"signals\":"
        + _signals_to_json(
            sig.has_error,
            ab2,
            conf2,
            res2,
            red2,
            sig.has_actuation,
            anode2,
            sig.has_interlock,
            ireason2,
            len(sig.telemetry),
        )
        + ",\"events\":[{\"type\":\"takt.tact_evaluated\",\"node_id\":"
        + quote(result.node_id)
        + ",\"outcome\":"
        + quote(outcome)
        + "}]}"
    )


def run_stdio_line(line: String) raises -> String:
    """One-line process step (Fala subprocess style)."""
    return cascade_step(line)
