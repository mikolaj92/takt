# Fala integration (subprocess effector)

Takt does **not** depend on Fala. Fala (or any process host) can run one cascade
step as a subprocess:

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

See [docs/FALA_INTEGRATION.md](../../docs/FALA_INTEGRATION.md).

`fala-package.toml` is a stub for hosts that wire effectors by package id.
