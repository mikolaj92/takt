"""Fala adapter boundary smoke (JSON cascade step)."""

from emberjson import Value
from takt.adapters_fala import cascade_step, run_stdio_line


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt fala stdio smoke: " + msg)


def main() raises:
    # Actuation path — node value outside tolerance
    var act = (
        "{"
        + "\"mode\":\"evaluate\","
        + "\"now\":\"2026-01-01T12:00:00Z\","
        + "\"plant_nodes\":[{\"id\":\"hunk:0\",\"value\":0.8,\"has_children\":false,\"layer\":0,\"kind\":\"hunk\"}],"
        + "\"layers\":[{\"layer\":0,\"tolerance\":0.1,\"min_confidence\":0.5,\"entropy_threshold\":0.35}]"
        + "}"
    )
    var out = cascade_step(act)
    _check(out.find("\"ok\":true") >= 0, "ok true")
    _check(out.find("\"outcome\":\"actuation\"") >= 0, "outcome actuation")
    _check(out.find("takt.tact_evaluated") >= 0, "event emitted")
    _check(out.find("\"reducer\":\"fallback\"") >= 0, "local reducer")

    # Interlock path — conflicting host detectors
    var il = (
        "{"
        + "\"mode\":\"evaluate\","
        + "\"plant_nodes\":[{\"id\":\"node\",\"value\":0.0,\"has_children\":false}],"
        + "\"layers\":[{\"layer\":0,\"tolerance\":0.1,\"min_confidence\":0.6,\"entropy_threshold\":0.35}],"
        + "\"raw_signals\":["
        + "{\"signal_id\":\"a\",\"deviation\":10.0,\"confidence\":0.9},"
        + "{\"signal_id\":\"b\",\"deviation\":-10.0,\"confidence\":0.9}"
        + "]"
        + "}"
    )
    var out_il = cascade_step(il)
    _check(out_il.find("\"outcome\":\"interlock\"") >= 0, "outcome interlock")
    _check(out_il.find("actuation\":null") >= 0 or out_il.find("\"actuation\":null") >= 0, "no actuation")

    # Multi-tact run
    var run = (
        "{"
        + "\"mode\":\"run\",\"steps\":3,"
        + "\"plant_nodes\":["
        + "{\"id\":\"root\",\"value\":0.0,\"has_children\":true,\"layer\":1,\"kind\":\"root\"},"
        + "{\"id\":\"n0\",\"value\":0.8,\"has_children\":false,\"parent_id\":\"root\",\"layer\":0,\"kind\":\"leaf\"}"
        + "],"
        + "\"layers\":[{\"layer\":0,\"tolerance\":0.1,\"min_confidence\":0.5}]"
        + "}"
    )
    var out_run = run_stdio_line(run)
    _check(out_run.find("\"mode\":\"run\"") >= 0, "run mode")
    _check(out_run.find("\"steps\":3") >= 0, "three steps")
    _check(out_run.find("takt.cascade_run") >= 0, "run event")

    # Full JSON boundary: Unicode and escaped input survive as valid JSON output.
    var unicode_request = (
        "{\"mode\":\"evaluate\",\"now\":\"2026-01-01T12:00:00Z\","
        + "\"plant_nodes\":[{\"id\":\"węzeł \\\"A\\\"\",\"value\":0.8}],"
        + "\"layers\":[{\"layer\":0,\"tolerance\":0.1,\"min_confidence\":0.5}]}"
    )
    var unicode_out = cascade_step(unicode_request)
    var parsed_out = Value(parse_string=unicode_out)
    _check(parsed_out.is_object(), "Unicode output is valid JSON")
    _check(
        parsed_out.object()["node_id"].string() == "węzeł \"A\"",
        "Unicode and escaping preserved",
    )

    # Malformed and structurally invalid wire requests fail closed.
    var rejected_invalid_json = False
    try:
        _ = cascade_step("{not-json}")
    except err:
        rejected_invalid_json = True
    _check(rejected_invalid_json, "invalid JSON rejected")

    var rejected_non_object = False
    try:
        _ = cascade_step("[]")
    except err:
        rejected_non_object = True
    _check(rejected_non_object, "non-object request rejected")

    var rejected_bad_array = False
    try:
        _ = cascade_step("{\"mode\":\"evaluate\",\"plant_nodes\":{}}")
    except err:
        rejected_bad_array = True
    _check(rejected_bad_array, "invalid plant_nodes shape rejected")

    var rejected_mode = False
    try:
        _ = cascade_step("{\"mode\":\"unknown\"}")
    except err:
        rejected_mode = True
    _check(rejected_mode, "unknown mode rejected")

    print("takt fala stdio smoke ok")
