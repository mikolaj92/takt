# takt

**Version 0.2.0** — exclusive Mojo hierarchical cascade engine.

**Takt is a fully Mojo library.** There is no Python runtime product tree.

## One job

> **Stabilize hierarchical state, tact by tact — descending constraints, ascending
> telemetry, fail-closed when entropy cannot be reduced.**

```text
  plant node (DFS tact)
        │
        ▼
  raw signals (wave + detectors + node value)
        │
        ▼
  fusion → ErrorSignal (aberration, confidence, residual)
        │
        ▼
  homeostat → Actuation | SafetyInterlock | stable
        │
        ▼
  ascending Wave (+ child layers when present)
```

Works the same over:

- document → section → paragraph  
- PR → file → hunk  
- any host-built numeric plant  

Takt does **not** parse documents or git. The host builds the plant and maps
actuations back to the world.

## Fully Mojo

| | |
| --- | --- |
| Language | **Mojo only** (`mojo/takt/`) |
| Proof | Mojo smokes (`mojo/smoke/`) |
| Host step | `tools/takt_step.sh` (Fala-compatible) |
| Python | **none** in the product tree |

```text
mojo/takt/     engine (+ step_main for host entry)
mojo/smoke/    gates
examples/      fixtures + cascade sketches
docs/          conceptual model + Fala boundary
tools/         mojo_run.sh, takt_step.sh
```

## Quick proof

Requires Mojo (Pixi or sibling Fala/Splot `.pixi` env via `tools/mojo_run.sh`):

```bash
./tools/mojo_run.sh mojo/smoke/full_smoke.mojo
./tools/mojo_run.sh mojo/smoke/fala_stdio.mojo
./tools/mojo_run.sh mojo/smoke/examples_plants.mojo
```

### One step as a subprocess (Fala-compatible)

```bash
export TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json
./tools/takt_step.sh
# With FALA_EFFECTOR_OUTPUT_DIR set, writes output/result.json
```

Success tokens: `takt … smoke ok`, JSON `"ok":true`.

## Core abstractions

| Name | Role |
| --- | --- |
| `TreeNode` / `MathTreePlant` | Hierarchical plant; `sequential_scan` = clock |
| `ProfilHomeostatyczny` | Layer tolerances, entropy / confidence gates |
| `SplotFusionUnit` | Local fusion (disagreement-aware fallback) |
| `CascadeRegulator` | One layer: collect → fuse → act / interlock |
| `TaktSequencer` | Multi-tact driver over plant + layer chain |
| `cascade_step` | Host JSON boundary (Fala / CLI) |

## Fusion (local)

- Empty raw list → aberration `0`, confidence `1`, residual `0`, reducer `empty`.  
- Agreeing signals → weighted-mean aberration, min confidence, residual ≥ `0.3`.  
- High spread → `fallback_disagreement`.  
- Opposing signs → `fallback_conflict`, low confidence, residual ≥ `0.85` (fail-closed).  

Optional **Splot** remains a separate organ the **host** may call before filling
`raw_signals` / node values — takt core never imports Splot.

## Examples

| Path | What |
| --- | --- |
| `examples/document-cascade/` | Document-shaped plant notes |
| `examples/code-cascade/` | PR / file / hunk notes |
| `examples/fala-integration/` | Subprocess effector wiring |
| `examples/multi-organ/` | Fala + Splot + Takt composition |
| `examples/fixtures/*.json` | Request payloads for `takt_step.sh` |

## Boundaries (hard)

| Outside Takt (host) | Inside Takt |
| --- | --- |
| Parsing docs / diffs / SDS | Numeric plant + DFS scan |
| LLMs, linters, sensors | Fusion of already-produced signals |
| Fala journals / scheduling | Evaluate / run envelope |
| Product UI | Actuation & interlock records |

## Related

- [fala](https://github.com/mikolaj92/Fala) — optional host / journal / effector runner  
- [splot](https://github.com/mikolaj92/splot) — optional multi-stream fusion organ  

## License

MIT
