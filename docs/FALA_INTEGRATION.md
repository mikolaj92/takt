# Fala integration (optional)

Takt does **not** depend on Fala. Fala can call Takt as a **subprocess / JSON
cascade step**.

Fala (or any host) owns:

- scheduling and process lifecycle  
- building the plant from domain sources (document, PR, sensors, …)  
- optional pre-fusion of detectors (e.g. via **Splot**)  
- journals / persistence  

Takt only runs cascade evaluate / multi-tact run under layer homeostats.

## Mapping

| Fala | Takt |
| --- | --- |
| Process / effector | `tools/takt_step.sh` → `cascade_step` |
| Input request | `plant_nodes` + `layers` (+ optional `raw_signals`) |
| Output | thin JSON: `outcome` / `results` + `events` |
| Domain packs | vocabulary only (optional, lives in Fala repo) |

## Input (JSON)

### Evaluate one tact

```json
{
  "mode": "evaluate",
  "plant_nodes": [
    {"id": "hunk:0", "value": 0.8, "has_children": false, "layer": 0, "kind": "hunk"}
  ],
  "layers": [
    {"layer": 0, "tolerance": 0.1, "min_confidence": 0.5, "entropy_threshold": 0.35}
  ],
  "now": "2026-01-01T12:00:00Z"
}
```

### Run N tacts

```json
{
  "mode": "run",
  "steps": 4,
  "plant_nodes": [ "… DFS list …" ],
  "layers": [ {"layer": 0, "tolerance": 0.1}, {"layer": 1, "tolerance": 0.2} ],
  "constraint_dev": 0.01
}
```

### Fail-closed via host detectors

```json
{
  "mode": "evaluate",
  "plant_nodes": [{"id": "node", "value": 0.0, "has_children": false}],
  "layers": [{"layer": 0, "tolerance": 0.1, "min_confidence": 0.6}],
  "raw_signals": [
    {"signal_id": "a", "deviation": 10.0, "confidence": 0.9},
    {"signal_id": "b", "deviation": -10.0, "confidence": 0.9}
  ]
}
```

## Output (JSON)

```json
{
  "ok": true,
  "mode": "evaluate",
  "outcome": "actuation",
  "node_id": "hunk:0",
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

| Env | Role |
| --- | --- |
| `TAKT_REQUEST_PATH` | Path to request JSON (local) |
| `FALA_EFFECTOR_INPUT_DIR` | Host input dir (`request.json`) |
| `FALA_EFFECTOR_OUTPUT_DIR` | Host output dir (`result.json`) |
| `FALA_PIXI_ENV` | Optional path to Mojo toolchain `bin/` |

## Proof

```bash
./tools/mojo_run.sh mojo/smoke/fala_stdio.mojo
TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json ./tools/takt_step.sh
```
