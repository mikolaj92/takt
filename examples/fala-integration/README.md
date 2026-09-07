# Fala integration (subprocess effector)

Takt does **not** depend on Fala. Fala (or any process host) can run one cascade
step as a subprocess. Canonical JSON / env contract:
[docs/FALA_INTEGRATION.md](../../docs/FALA_INTEGRATION.md). Cascade model:
[docs/CONCEPTUAL_MODEL.md](../../docs/CONCEPTUAL_MODEL.md).

```bash
export FALA_EFFECTOR_INPUT_DIR=...   # contains request.json
export FALA_EFFECTOR_OUTPUT_DIR=...  # receives result.json
./tools/takt_step.sh
```

Local fixture (no Fala):

```bash
TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json ./tools/takt_step.sh
./tools/mojo_run.sh mojo/smoke/fala_stdio.mojo
```

`fala-package.toml` is a stub for hosts that wire effectors by package id.
