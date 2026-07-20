# Takt conceptual model

## One job

> **Stabilize hierarchical state, tact by tact, under descending constraints and
> ascending telemetry — fail closed when fusion cannot reduce entropy.**

## Core loop (one tact)

1. **Plant** yields the next `StateNode` (`sequential_scan`, DFS).  
2. **CascadeRegulator** collects raw signals (wave constraints, detectors, node value).  
3. **Fusion** reduces raw signals → `ErrorSignal` (aberration, confidence, residual).  
4. **Homeostat** decides: stable / `Actuation` / `SafetyInterlock`.  
5. **Wave** ascends (and may descend into child layers).

## Layers

`L0 … Ln-1` each have a `ProfilHomeostatyczny` (tolerances, entropy threshold,
min confidence). Higher layers send constraints down; lower layers report up.

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
