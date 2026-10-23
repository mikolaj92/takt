# Takt conceptual model

Canonical one-job, tact loop, fusion rules, and host/inside boundaries. JSON / Fala subprocess contract: [FALA_INTEGRATION.md](FALA_INTEGRATION.md).

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

Takt does **not** parse documents or git. The host builds the plant and maps actuations back to the world.

## Core loop (one tact)

1. **Plant** yields the next `StateNode` (`sequential_scan`, DFS).
2. **CascadeRegulator** starts at the highest regulator, regardless of `TreeNode.layer` metadata.
3. **Fusion** in each evaluated regulator reduces wave constraints, its buffered detectors, and node value → `ErrorSignal`.
4. **Homeostat** decides: stable / `Actuation` / `SafetyInterlock`.
5. **Wave** carries results; lower regulators evaluate the same node only when `has_children` is true.

## Layers

`L0 … Ln-1` each have a `ProfilHomeostatyczny` (tolerances, entropy threshold, min confidence); the last chain entry is highest.
In JSON `evaluate`, the adapter copies `raw_signals` only to the highest regulator's one-shot `extra_raw` buffer.
That regulator consumes and clears its buffer during `evaluate`; lower regulators receive only resulting constraints.
A leaf with L0 and L1 evaluates only L1: L1 consumes detectors, while L0 does not evaluate.
Descent passes resulting `aberration` / `confidence` constraints, not raw detectors; lower regulators report up. `TreeNode.layer` does not select a regulator.

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

Optional **Splot** remains a separate organ the **host** may call before filling `raw_signals` / node values — takt core never imports Splot.

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
