# Document cascade example

Models a **document → section → paragraph** plant. Node `value` is a host-supplied
aberration proxy (any evaluator may produce it — LLM rubric, heuristic, human).

Takt has **no document parser**. The host builds `plant_nodes` (or uses
`make_document_plant` in Mojo) and runs the cascade.

```bash
# Multi-tact run over a document-shaped plant
TAKT_REQUEST_PATH=examples/fixtures/cascade_run.request.json ./tools/takt_step.sh
```

Expected: JSON envelope with `mode:run`, advancing tacts over `doc`, sections,
and paragraphs; high-deviation paragraph produces actuation when confidence allows.
