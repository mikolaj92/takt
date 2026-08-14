# Approach plan

<!-- lokay-approach source=deterministic repo=mikolaj92/takt issue=25 -->

Repository: `mikolaj92/takt`  
Issue: #25 — README/pixi na mainie nadal v0.2.0, tree jest 0.3.0 z python/takt

## Goal

Align `main` product stamps with the 0.3.0 tree (`python/takt`). README/pixi must not still advertise exclusive-Mojo 0.2.0 (`Version 0.2.0`, „There is no Python runtime product tree”, `--branch v0.2.0`, `takt-0.2.0.tar.gz`).

Inspection: stamps were already 0.3.0 after #26. Lock the #25 leftovers with a regression test rather than restamping.

## Files likely touched

- `python/tests/test_python_binding.py`
- `CHANGELOG.md`
- `pixi.toml` / `pyproject.toml` / `README.md` (already 0.3.0; no restamp)

## Test plan

- `uv run pytest python/tests/test_python_binding.py::test_product_stamps_are_030_not_leftover_mojo_only_020`

## Non-goals

- (none stated)

## Notes

- Trust intentional issue; this plan is evidence for later review, not a human gate.
- Coding agent may refine details but should stay on the stated goal and non-goals.
- Collector boundary: if implementation introduces unbounded collection, ship only a bounded collector patch that starts durably in the background after merge. The coding agent and mill must not populate data or wait for collection to finish.
