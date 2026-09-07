# Takt conceptual model

Canonical one-job, tact loop, fusion rules, and host/inside boundaries.
JSON / Fala subprocess contract: [FALA_INTEGRATION.md](FALA_INTEGRATION.md).

## One job

> **Stabilize hierarchical state, tact by tact, under descending constraints and
> ascending telemetry — fail closed when fusion cannot reduce entropy.**

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

## Core loop (one tact)

1. **Plant** yields the next `StateNode` (`sequential_scan`, DFS).
2. **CascadeRegulator** collects raw signals (wave constraints, detectors, node value).
3. **Fusion** reduces raw signals → `ErrorSignal` (aberration, confidence, residual).
4. **Homeostat** decides: stable / `Actuation` / `SafetyInterlock`.
5. **Wave** ascends (and may descend into child layers).

## Layers

`L0 … Ln-1` each have a `ProfilHomeostatyczny` (tolerances, entropy threshold,
min confidence). Higher layers send constraints down; lower layers report up.

## Core abstractions

| Name | Role |
| --- | --- |
| `TreeNode` / `MathTreePlant` | Hierarchical plant; `sequential_scan` = clock |
| `ProfilHomeostatyczny` | Layer tolerances, entropy / confidence gates |
| `SplotFusionUnit` | Local fusion (disagreement-aware fallback) |
| `CascadeRegulator` | One layer: collect → fuse → act / interlock |
| `TaktSequencer` | Multi-tact driver over plant + layer chain |
| `cascade_step` | Host JSON boundary (Fala / CLI), parsed by EmberJson |

## Fusion (local)

- Empty raw list → aberration `0`, confidence `1`, residual `0`, reducer `empty`.
- Agreeing signals → weighted-mean aberration, min confidence, residual ≥ `0.3`.
- High spread → `fallback_disagreement`.
- Opposing signs → `fallback_conflict`, low confidence, residual ≥ `0.85` (fail-closed).

Optional **Splot** remains a separate organ the **host** may call before filling
`raw_signals` / node values — takt core never imports Splot.

## Boundaries

| Outside Takt (host) | Inside Takt |
| --- | --- |
| Parsing documents / git / SDS | Numeric plant + scan order |
| Running LLMs / linters / sensors | Fusion of already-produced raw signals |
| Fala journals / multi-process schedule | One evaluate / run envelope |
| Product UI | Actuation & interlock records |

## Related organs

- **Splot** — many streams → one commitment (optional pre-step per node).
- **Fala** — optional host / transport / journal (subprocess effector).
