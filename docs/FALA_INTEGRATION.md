# Fala integration (optional)

Fala optionally calls Takt as a **subprocess / JSON cascade step**.
See [CONCEPTUAL_MODEL.md](CONCEPTUAL_MODEL.md) for host/core boundaries.
This is the canonical JSON / effector contract; do not copy examples into README or `examples/*/README.md`.

Fala (or any host) owns:

- scheduling and process lifecycle
- building the plant from domain sources (document, PR, sensors, …)
- optional pre-fusion of detectors (e.g. via **Splot**)
- journals / persistence

`adapters_fala` parses JSON with EmberJson; the cascade core uses typed Mojo structures.

## Mapping

| Fala | Takt |
| --- | --- |
| Process / effector | `tools/takt_step.sh` → `cascade_step` |
| Input request | `plant_nodes` + `layers` (+ optional `raw_signals`) |
| Output | thin JSON: `outcome` / `results` + `events` |
| Domain packs | vocabulary only (optional, lives in Fala repo) |

## Input (JSON)

Both modes accept an optional `incoming_constraints` object with optional numeric `dev` / `policy`.
`incoming_constraints.dev` overrides `constraint_dev`; omission or `null` preserves `constraint_dev` without adding constraints.
Other non-object values raise `takt: incoming_constraints must be a JSON object`.
Each `layers[]` entry accepts numeric `cutoff` (default `0.01`).
Wrong numeric types, including `null`, use defaults: `constraint_dev`, `dev` and `policy` use `0.0`; `cutoff` uses `0.01`.

### Evaluate one tact

`mode` defaults to `evaluate`, which requires exactly one node after DFS scan; empty or omitted `plant_nodes` keeps the single-node fallback.
`plant_nodes[].layer` (`TreeNode.layer`, default `0`) remains accepted as metadata, not a regulator selector.
Omitted signal `node_id` defaults to the evaluated node; explicit IDs are preserved. Any mismatched ID rejects evaluation before injection.
The adapter copies `raw_signals` only into the highest regulator's one-shot `extra_raw` buffer; its next `evaluate` consumes and clears it.
The sequencer starts at the highest regulator (last `layers[]` entry; supply layers in ascending order). A leaf (`has_children: false`) never evaluates lower regulators.
Only evaluated regulators run fusion. Descent passes the parent's resulting `aberration` / `confidence` constraints, without reinjecting raw detectors. `cascade_descent.request.json` derives interlock from constraints alone versus actuation with former all-regulator injection; these are expected, not executed results.

```json
{
  "mode": "evaluate",
  "plant_nodes": [{"id": "hunk:0", "value": 0.8, "has_children": false, "layer": 0, "kind": "hunk"}],
  "layers": [
    {"layer": 0, "tolerance": 0.1, "min_confidence": 0.5, "entropy_threshold": 0.35, "cutoff": 0.01}
  ],
  "now": "2026-01-01T12:00:00Z"
}
```

### Run N tacts

```json
{
  "mode": "run",
  "steps": 4,
  "plant_nodes": [{"id": "node", "value": 0.8, "has_children": false, "layer": 0}],
  "layers": [ {"layer": 0, "tolerance": 0.1}, {"layer": 1, "tolerance": 0.2} ],
  "constraint_dev": 0.01,
  "incoming_constraints": {"dev": 0.02, "policy": 0.03}
}
```

### Fail-closed via host detectors (leaf: only L1 consumes detectors; L0 does not evaluate)

```json
{
  "mode": "evaluate",
  "plant_nodes": [{"id": "node", "value": 0.0, "has_children": false}],
  "layers": [{"layer": 0, "tolerance": 0.1, "min_confidence": 0.6}, {"layer": 1, "tolerance": 0.1, "min_confidence": 0.6}],
  "raw_signals": [
    {"signal_id": "a", "deviation": 10.0, "confidence": 0.9},
    {"signal_id": "b", "deviation": -10.0, "confidence": 0.9}
  ]
}
```

## Output (JSON)

```json
{
  "ok": true, "mode": "evaluate", "outcome": "actuation", "node_id": "hunk:0",
  "signals": {
    "error": {"aberration": 0.8, "confidence": 0.8, "residual_entropy": 0.3, "reducer": "fallback"},
    "actuation": {"node_id": "hunk:0", "command": "correct_aberration"},
    "interlock": null,
    "telemetry_count": 1
  },
  "events": [{"type": "takt.tact_evaluated", "node_id": "hunk:0", "outcome": "actuation"}]
}
```

## Effector env

Explicit input via `TAKT_REQUEST_PATH` or `FALA_EFFECTOR_INPUT_DIR` is required; without it, the process returns an error.

| Env | Role |
| --- | --- |
| `TAKT_REQUEST_PATH` | Path to request JSON (local) |
| `FALA_EFFECTOR_INPUT_DIR` | Host input dir (`request.json`) |
| `FALA_EFFECTOR_OUTPUT_DIR` | Host output dir (`result.json`) |
| `FALA_PIXI_ENV` | Optional path to Mojo toolchain `bin/` |

## Proof

```bash
./tools/mojo_run.sh mojo/smoke/fala_stdio.mojo
TAKT_REQUEST_PATH=examples/fixtures/cascade_descent.request.json ./tools/takt_step.sh
```
