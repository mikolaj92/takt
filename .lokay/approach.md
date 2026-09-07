# Approach plan

<!-- lokay-approach source=deterministic repo=mikolaj92/takt issue=44 -->

Repository: `mikolaj92/takt`  
Issue: #44 — Cleanup: Docs dual-path — README vs `docs/` vs examples

## Goal

Ten sam model / kontrakt Fala żyje w trzech warstwach:

## Files likely touched

- `docs/CONCEPTUAL_MODEL.md` (canonical one-job, tact, fusion, boundaries)
- `docs/FALA_INTEGRATION.md` (canonical Fala/JSON contract)
- `README.md` (layout / Get Takt / Quick proof + docs pointers)
- `examples/fala-integration/README.md`
- `examples/multi-organ/README.md`
- `python/tests/test_python_binding.py` (drift guard)
- `CHANGELOG.md`

## Test plan

- Kanoniczny conceptual model: wyłącznie `docs/CONCEPTUAL_MODEL.md` (albo wyłącznie README — wybór jeden)
- Kanoniczny Fala/JSON kontrakt: wyłącznie `docs/FALA_INTEGRATION.md`
- README trzyma layout / Get Takt / Quick proof i **linkuje** docs zamiast dublować tabele Boundaries + pełny model
- `examples/fala-integration/README.md` i `examples/multi-organ/README.md` linkują docs; bez drugiej kopii JSON schema
- Brak sprzecznych sformułowań one-job / Outside-Inside między plikami (spot-check diff)

## Non-goals

- Nowe feature docs. Tłumaczenie całości. Zmiana JSON wire format.

## Notes

- Trust intentional issue; this plan is evidence for later review, not a human gate.
- Coding agent may refine details but should stay on the stated goal and non-goals.
- Collector boundary: if implementation introduces unbounded collection, ship only a bounded collector patch that starts durably in the background after merge. The coding agent and lokay must not populate data or wait for collection to finish.
