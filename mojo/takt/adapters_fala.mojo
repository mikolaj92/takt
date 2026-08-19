"""Fala / process-host boundary: JSON in → one cascade step out.

Takt does not import Fala. The host owns scheduling, plant construction from
domain sources, and persistence. EmberJson is confined to this wire adapter;
the cascade core receives typed Mojo values.
"""

from std.collections import List, Dict
from emberjson import Value, to_string
from takt.builder import LayerSpec, build_cascade
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.plant import MathTreePlant, TreeNode, make_layered_plant
from takt.sequencer import TaktSequencer
from takt.types import RawSignal, Wave


def _quote(value: String) -> String:
    return to_string(Value(value))


def _object(root: Value, key: String) raises -> Value:
    if not root.is_object() or key not in root.object():
        return Value()
    return root.object()[key].copy()


def _string(root: Value, key: String, default: String = "") raises -> String:
    var item = _object(root, key)
    if item.is_string():
        return item.string()
    return default


def _float(root: Value, key: String, default: Float64 = 0.0) raises -> Float64:
    var item = _object(root, key)
    if item.is_float():
        return item.float()
    if item.is_int():
        return Float64(item.int())
    if item.is_uint():
        return Float64(item.uint())
    return default


def _int(root: Value, key: String, default: Int = 0) raises -> Int:
    var item = _object(root, key)
    if item.is_int():
        return Int(item.int())
    if item.is_uint():
        return Int(item.uint())
    return default


def _bool(root: Value, key: String, default: Bool = False) raises -> Bool:
    var item = _object(root, key)
    if item.is_bool():
        return item.bool()
    return default


def _array(root: Value, key: String) raises -> Value:
    var item = _object(root, key)
    if item.is_null():
        return Value(parse_string="[]")
    if not item.is_array():
        raise Error("takt: " + key + " must be a JSON array")
    return item^


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
            + _quote(actuation_node)
            + ",\"command\":\"correct_aberration\"}"
        )
    var il = "null"
    if has_interlock:
        il = (
            "{\"reason\":"
            + _quote(interlock_reason)
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
            + _quote(reducer)
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


def _parse_layers(root: Value) raises -> List[LayerSpec]:
    var specs = List[LayerSpec]()
    var layers = _array(root, "layers")
    if len(layers.array()) == 0:
        var h = ProfilHomeostatyczny(0)
        h.add_variable(EssentialVariable("dev", _float(root, "tolerance", 0.1), 0.01))
        h.min_confidence = _float(root, "min_confidence", 0.6)
        h.entropy_threshold = _float(root, "entropy_threshold", 0.35)
        specs.append(LayerSpec(0, h))
        return specs^

    for i in range(len(layers.array())):
        var item = layers.array()[i].copy()
        if not item.is_object():
            raise Error("takt: layers entries must be JSON objects")
        var layer = _int(item, "layer", i)
        var h = ProfilHomeostatyczny(
            layer,
            _float(item, "entropy_threshold", 0.35),
            _float(item, "min_confidence", 0.6),
        )
        h.add_variable(
            EssentialVariable(
                "dev",
                _float(item, "tolerance", 0.1),
                _float(item, "cutoff", 0.01),
            )
        )
        specs.append(LayerSpec(layer, h))
    return specs^


def _parse_plant(root: Value) raises -> MathTreePlant:
    var plant_nodes = _array(root, "plant_nodes")
    if len(plant_nodes.array()) == 0:
        var nid = _string(root, "node_id", "node")
        var nval = _float(root, "node_value", 0.0)
        if root.is_object() and "id" in root.object():
            nid = _string(root, "id", nid)
        if root.is_object() and "value" in root.object():
            nval = _float(root, "value", nval)
        var nodes = List[TreeNode]()
        nodes.append(TreeNode(nid, nval, False, "", 0, "node"))
        return make_layered_plant(nodes^)

    var nodes = List[TreeNode]()
    for i in range(len(plant_nodes.array())):
        var item = plant_nodes.array()[i].copy()
        if not item.is_object():
            raise Error("takt: plant_nodes entries must be JSON objects")
        nodes.append(
            TreeNode(
                _string(item, "id", "n" + String(i)),
                _float(item, "value", 0.0),
                _bool(item, "has_children", False),
                _string(item, "parent_id", ""),
                _int(item, "layer", 0),
                _string(item, "kind", "node"),
            )
        )
    return make_layered_plant(nodes^)


def _parse_raw(root: Value, node_id: String) raises -> List[RawSignal]:
    var out = List[RawSignal]()
    var raw_signals = _array(root, "raw_signals")
    for i in range(len(raw_signals.array())):
        var item = raw_signals.array()[i].copy()
        if not item.is_object():
            raise Error("takt: raw_signals entries must be JSON objects")
        out.append(
            RawSignal(
                _string(item, "signal_id", "s" + String(i)),
                _string(item, "node_id", node_id),
                _string(item, "detector", "host"),
                _float(item, "deviation", 0.0),
                _float(item, "confidence", 1.0),
            )
        )
    return out^


def _parse_constraints(root: Value) raises -> Dict[String, Float64]:
    var constraints = Dict[String, Float64]()
    if root.is_object() and "constraint_dev" in root.object():
        constraints["dev"] = _float(root, "constraint_dev", 0.0)
    var incoming = _object(root, "incoming_constraints")
    if incoming.is_object():
        if "dev" in incoming.object():
            constraints["dev"] = _float(incoming, "dev", 0.0)
        if "policy" in incoming.object():
            constraints["policy"] = _float(incoming, "policy", 0.0)
    elif not incoming.is_null():
        raise Error("takt: incoming_constraints must be a JSON object")
    return constraints^


def cascade_step(input_json: String) raises -> String:
    """Run one typed cascade evaluation or multi-tact run from host JSON."""
    var root = Value(parse_string=input_json)
    if not root.is_object():
        raise Error("takt: request must be a JSON object")

    var mode = _string(root, "mode", "evaluate")
    if mode != "evaluate" and mode != "run":
        raise Error("takt: mode must be evaluate or run")
    var now = _string(root, "now", "2026-01-01T00:00:00Z")
    var specs = _parse_layers(root)
    var chain = build_cascade(specs^)
    var plant = _parse_plant(root)
    var constraints = _parse_constraints(root)
    var has_wave = len(constraints) > 0
    var top_layer = chain.root().layer
    var wave = Wave("host_top", top_layer, "host", "", constraints.copy())

    if mode == "run":
        var steps = _int(root, "steps", plant.node_count())
        if steps < 0:
            raise Error("takt: steps must be non-negative")
        var seq = TaktSequencer(plant, chain)
        var results = seq.run(steps, has_wave, wave)
        var items = String("[")
        for i in range(len(results)):
            if i > 0:
                items += ","
            var result = results[i].copy()
            var signals = result.signals.copy()
            var aberration: Float64 = 0.0
            var confidence: Float64 = 1.0
            var residual: Float64 = 0.0
            var reducer = String("none")
            if signals.has_error:
                aberration = signals.error.aberration
                confidence = signals.error.confidence
                residual = signals.error.residual_entropy
                reducer = signals.error.reducer
            var actuation_node = String("")
            if signals.has_actuation:
                actuation_node = signals.actuation.node_id
            var interlock_reason = String("")
            if signals.has_interlock:
                interlock_reason = signals.interlock.reason
            items += (
                "{\"tact\":"
                + String(result.tact)
                + ",\"node_id\":"
                + _quote(result.node_id)
                + ",\"node_value\":"
                + String(result.node_value)
                + ",\"signals\":"
                + _signals_to_json(
                    signals.has_error,
                    aberration,
                    confidence,
                    residual,
                    reducer,
                    signals.has_actuation,
                    actuation_node,
                    signals.has_interlock,
                    interlock_reason,
                    len(signals.telemetry),
                )
                + "}"
            )
        items += "]"
        return (
            "{\"ok\":true,\"mode\":\"run\",\"now\":"
            + _quote(now)
            + ",\"steps\":"
            + String(len(results))
            + ",\"results\":"
            + items
            + ",\"events\":[{\"type\":\"takt.cascade_run\",\"steps\":"
            + String(len(results))
            + "}]}"
        )

    var nodes = plant.sequential_scan()
    var node = nodes[0].copy()
    var raw = _parse_raw(root, node.id)
    if len(raw) > 0:
        for layer_index in range(len(chain.layers)):
            var regulator = chain.layers[layer_index].copy()
            regulator.inject_raw(raw.copy())
            chain.layers[layer_index] = regulator^

    var sequencer = TaktSequencer(plant, chain)
    var result = sequencer.run_one_tact(has_wave, wave)
    var signals = result.signals.copy()
    var outcome = "stable"
    if signals.has_interlock:
        outcome = "interlock"
    elif signals.has_actuation:
        outcome = "actuation"

    var aberration: Float64 = 0.0
    var confidence: Float64 = 1.0
    var residual: Float64 = 0.0
    var reducer = String("none")
    if signals.has_error:
        aberration = signals.error.aberration
        confidence = signals.error.confidence
        residual = signals.error.residual_entropy
        reducer = signals.error.reducer
    var actuation_node = String("")
    if signals.has_actuation:
        actuation_node = signals.actuation.node_id
    var interlock_reason = String("")
    if signals.has_interlock:
        interlock_reason = signals.interlock.reason

    return (
        "{\"ok\":true,\"mode\":\"evaluate\",\"now\":"
        + _quote(now)
        + ",\"tact\":"
        + String(result.tact)
        + ",\"node_id\":"
        + _quote(result.node_id)
        + ",\"outcome\":"
        + _quote(outcome)
        + ",\"signals\":"
        + _signals_to_json(
            signals.has_error,
            aberration,
            confidence,
            residual,
            reducer,
            signals.has_actuation,
            actuation_node,
            signals.has_interlock,
            interlock_reason,
            len(signals.telemetry),
        )
        + ",\"events\":[{\"type\":\"takt.tact_evaluated\",\"node_id\":"
        + _quote(result.node_id)
        + ",\"outcome\":"
        + _quote(outcome)
        + "}]}"
    )


def run_stdio_line(line: String) raises -> String:
    """One-line process step (Fala subprocess style)."""
    return cascade_step(line)
