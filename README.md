# takt

**Version 0.3.2** — Mojo hierarchical cascade engine + optional thin Python binding.

Canonical product version is `[project].version` in `pyproject.toml`; other stamps are checked against it.

**Takt is a Mojo library.** The engine lives in `mojo/takt/`. An optional
in-process Python host API (`python/takt`) wraps the same cascade step;
`tools/takt_step.sh` stays the official Fala subprocess contract. No dual engine.

Canonical conceptual model (one job, tact loop, fusion, host/inside
boundaries): [docs/CONCEPTUAL_MODEL.md](docs/CONCEPTUAL_MODEL.md).
Fala / JSON subprocess contract:
[docs/FALA_INTEGRATION.md](docs/FALA_INTEGRATION.md).

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
tools/         dependency setup, mojo_run.sh, takt_step.sh
vendor/        dynamically managed EmberJson sources (gitignored)
```

## Get Takt 0.3.2

The GitHub default branch is the current product tree. Pin release `v0.3.2`
when a consumer needs reproducible dependency resolution; reviewkit uses that
exact release boundary.

Sibling organs are packages **`fala`** and **`splot`**, not `*-runtime`.
Takt 0.3.2 does not depend on them.

```bash
# Recommended: pin the product tag
git clone --branch v0.3.2 --depth 1 https://github.com/mikolaj92/takt.git
cd takt

# Or download the source archive
curl -fsSL -o takt-0.3.2.tar.gz \
  https://github.com/mikolaj92/takt/archive/refs/tags/v0.3.2.tar.gz
tar -xzf takt-0.3.2.tar.gz && cd takt-0.3.2
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

Requires stable Mojo 1.0 (`pixi` env from this repo, or sibling Fala `.pixi`).
The run scripts pin, fetch, and patch the gitignored EmberJson dependency used
only at the JSON process boundary.

Release notes & archives: https://github.com/mikolaj92/takt/releases/tag/v0.3.2

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

Requires stable Mojo 1.0 (Pixi or sibling Fala `.pixi` env via `tools/mojo_run.sh`):

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

## Examples

| Path | What |
| --- | --- |
| `examples/document-cascade/` | Document-shaped plant notes |
| `examples/code-cascade/` | PR / file / hunk notes |
| `examples/fala-integration/` | Subprocess effector wiring |
| `examples/multi-organ/` | Fala + Splot + Takt composition |
| `examples/fixtures/*.json` | Request payloads for `takt_step.sh` |

## Related

- [fala](https://github.com/mikolaj92/Fala) — optional host / journal / effector runner
- [splot](https://github.com/mikolaj92/splot) — optional multi-stream fusion organ

## License

MIT
