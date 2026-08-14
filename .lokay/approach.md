# Approach plan

<!-- lokay-approach source=deterministic repo=mikolaj92/takt issue=25 -->

Repository: `mikolaj92/takt`  
Issue: #25 — README/pixi na mainie nadal v0.2.0, tree jest 0.3.0 z python/takt

## Goal

Na `main`: README Version 0.2.0, „There is no Python runtime product tree”, clone `--branch v0.2.0`, archive `takt-0.2.0.tar.gz`.
`pixi.toml` version 0.2.0.

## Files likely touched

- `takt-0.2.0.tar.gz`
- `pixi.toml`
- `pyproject.toml`

## Test plan

- Run the smallest useful tests for files touched

## Non-goals

- (none stated)

## Notes

- Trust intentional issue; this plan is evidence for later review, not a human gate.
- Coding agent may refine details but should stay on the stated goal and non-goals.
- Collector boundary: if implementation introduces unbounded collection, ship only a bounded collector patch that starts durably in the background after merge. The coding agent and mill must not populate data or wait for collection to finish.
