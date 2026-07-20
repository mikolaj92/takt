# Code / PR cascade example

Models a **pull_request → file → hunk** plant — the same cascade core as
documents, different `kind` labels only.

```bash
# Single-hunk evaluate (actuation outside tolerance)
TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json ./tools/takt_step.sh
```

In Mojo tests/smokes use `make_code_plant(file_devs, hunk_devs)`.

Host responsibilities (outside takt):

- parse git/diff / GitHub PR into DFS nodes
- fill each node’s numeric deviation (lint, policy, model score, …)
- map `Actuation` / `SafetyInterlock` back to review comments or checks
