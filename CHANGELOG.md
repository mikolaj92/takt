# Changelog

## 0.3.1

- Tag the already-migrated Mojo **1.0.0** `main` line for consumers.
- Prefer this checkout's Pixi `mojo == 1.0.0` over a global nightly SDK when compiling `_native`.
- Pin the product toolchain to stable Mojo 1.0.0 instead of a nightly build.
- Replace the partial in-tree `json_lite` parser with pinned EmberJson at the
  Fala/CLI wire boundary; the cascade core remains fully typed Mojo.
- Add strict JSON shape validation plus Unicode, escaping, and malformed-input
  contract coverage.
- Dynamically fetch and apply the shared Mojo 1.0 EmberJson compatibility patch.

## 0.3.0

**Thin optional Python binding** over the exclusive Mojo cascade engine.

### Added
- `python/takt/`: `cascade_step` (same JSON as `tools/takt_step.sh`)
- JIT `_native` extension compile helper
- Python smoke tests

### Docs / packaging
- Product stamps (README, `pixi.toml`, Mojo `TAKT_VERSION`, fala-package) are 0.3.0.
- README / pixi no longer advertise leftover exclusive-Mojo 0.2.0 (`v0.2.0` clone, `takt-0.2.0.tar.gz`).
- Pin tag `v0.3.0` — an unpinned clone follows GitHub default `develop` (stale Python 0.1.0).
- Sibling organs are packages `fala` / `splot`, not `fala-runtime` / `splot-runtime`.
- Dev extra: `uv sync --extra dev` (`[project.optional-dependencies]`; not `uv sync --dev`).

### Unchanged
- Mojo engine, subprocess step, no dual engine


Takt follows semantic versioning.

## 0.2.0

**Exclusive Mojo cascade engine** — product tree is Mojo-only (like Fala/Splot).

### Product

- Mojo engine under `mojo/takt/`: plant scan → local fusion → homeostat →
  actuation / interlock → multi-layer sequencer.
- **No Python runtime** in the product tree (`src/`, pytest suite removed).
- `pyproject.toml` is metadata-only (hatch wheel includes README only).

### Fusion

- Local fallback is still always-on (no mandatory Splot).
- **Disagreement / conflict residual**: opposing-sign detectors collapse
  confidence and raise residual entropy (`fallback_conflict`); high spread marks
  `fallback_disagreement`.

### Plant

- Nodes carry `parent_id`, `layer`, `kind`.
- Builders: `make_document_plant`, `make_code_plant`, `make_layered_plant`
  (document / PR-shaped DFS plants without domain parsers).

### Fala effector

- `mojo/takt/adapters_fala.mojo` — `cascade_step` / `run_stdio_line` JSON boundary.
- `mojo/takt/step_main.mojo` + `tools/takt_step.sh` — Fala-compatible subprocess
  (`FALA_EFFECTOR_*` / `TAKT_REQUEST_PATH` → `result.json`).
- Fixtures under `examples/fixtures/`; smoke `fala_stdio`.

### Examples & docs

- `examples/document-cascade`, `code-cascade`, `fala-integration`, `multi-organ`.
- `docs/FALA_INTEGRATION.md`, `docs/CONCEPTUAL_MODEL.md`.

### Proof

```bash
./tools/mojo_run.sh mojo/smoke/full_smoke.mojo
./tools/mojo_run.sh mojo/smoke/fala_stdio.mojo
TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json ./tools/takt_step.sh
```

## 0.1.2

- Python package: decouple from Fala runtime; local Wave + optional splot.

## 0.1.0

- Initial Python cascade library (types, homeostat, plant, fusion, regulator,
  sequencer, builder).
