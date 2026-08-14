# takt

**Version 0.3.0** — Mojo hierarchical cascade engine + optional thin Python binding.

**Takt is a Mojo library.** The engine lives in `mojo/takt/`. An optional
in-process Python host API (`python/takt`) wraps the same cascade step;
`tools/takt_step.sh` stays the official Fala subprocess contract. No dual engine.

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

## Layout

| | |
| --- | --- |
| Language | **Mojo engine** (`mojo/takt/`) |
| Proof | Mojo smokes (`mojo/smoke/`) + optional Python binding tests |
| Host step | `tools/takt_step.sh` (Fala-compatible) |
| Python | **optional thin binding** (`python/takt`) — same JSON contract |

```text
mojo/takt/     engine (+ step_main for host entry)
mojo/smoke/    gates
python/takt/   optional in-process host API (`cascade_step`)
examples/      fixtures + cascade sketches
docs/          conceptual model + Fala boundary
tools/         mojo_run.sh, takt_step.sh
```

## Get Takt 0.3.0

Pin a release. An unpinned `git clone` follows GitHub's default branch and is
**not** the product tree (historical Python 0.1.0 with `fala-runtime` /
`splot-runtime` path deps). The product is **0.3.0** on `main` / tag `v0.3.0`.
reviewkit pins `takt @ …/takt.git@v0.3.0`.

Sibling organs are packages **`fala`** and **`splot`**, not `*-runtime`.
Takt 0.3.0 does not depend on them.

```bash
# Recommended: pin the product tag
git clone --branch v0.3.0 --depth 1 https://github.com/mikolaj92/takt.git
cd takt

# Or download the source archive
curl -fsSL -o takt-0.3.0.tar.gz \
  https://github.com/mikolaj92/takt/archive/refs/tags/v0.3.0.tar.gz
tar -xzf takt-0.3.0.tar.gz && cd takt-0.3.0
```

**Use as a Mojo import path** (from any host project):

```bash
mojo run -I /path/to/takt/mojo your_program.mojo
# inside Mojo:
#   from takt.sequencer import TaktSequencer
#   from takt.adapters_fala import cascade_step
```

**Run the Fala-compatible step** (no install beyond Mojo toolchain):

```bash
export TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json
./tools/takt_step.sh
```

Requires a Mojo toolchain (`pixi` env from this repo, or sibling Fala/Splot
`.pixi` — `tools/mojo_run.sh` / `tools/takt_step.sh` locate it).

Release notes & archives: https://github.com/mikolaj92/takt/releases/tag/v0.3.0

### Optional Python binding

Mojo remains the product engine. An optional in-process host API:

```bash
export TAKT_HOME=/path/to/takt   # if not developing from the checkout
# Mojo toolchain on PATH (pixi / Modular)
uv sync --extra dev
uv run pytest
```

`[project.optional-dependencies] dev` is an extra — use `uv sync --extra dev`
(not `uv sync --dev`). `uv sync --group dev` also works via `[dependency-groups]`.

```python
import takt
result = takt.cascade_step({"mode": "evaluate", "plant_nodes": [...], "layers": [...]})
# same JSON as tools/takt_step.sh
```

Requires Mojo on PATH (or sibling Fala pixi). `tools/takt_step.sh` remains the
Fala subprocess contract. No dual engine.

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
