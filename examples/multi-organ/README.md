# Multi-organ composition (Fala + Splot + Takt)

These three organs stay **separate processes / libraries**:

| Organ | Job |
| --- | --- |
| **Fala** | Host: schedule, journal, impulses, subprocess effectors |
| **Splot** | Fuse many high-entropy candidate streams → one commitment |
| **Takt** | Hierarchical cascade over a plant tree → actuation / interlock |

## Suggested host flow

```text
  domain source (doc / PR / sensors)
           │
           ▼
     Fala process (schedule)
        │              │
        │              ├──▶ Splot step (optional): fuse multi-detector scores
        │              │         into one deviation/confidence per node
        │              ▼
        └──▶ Takt step: plant DFS + cascade homeostats
                   │
                   ▼
              Actuation / SafetyInterlock / ascending Wave
                   │
                   ▼
              Fala journals + domain effectors (comments, gates, …)
```

## What lives where

- **Plant construction** (parse markdown, git diff, SDS) — host / domain kit, not takt.
- **Detector scores** — host evaluators; optionally **Splot** reduces them per node.
- **Layer tolerances / fail-closed** — Takt `ProfilHomeostatyczny`.
- **Persistence / multi-step workflows** — Fala.

## Local proofs (sibling checkouts)

```bash
# Takt cascade step
cd ../takt && TAKT_REQUEST_PATH=examples/fixtures/cascade_run.request.json ./tools/takt_step.sh

# Splot fusion step
cd ../Splot && SPLOT_REQUEST_PATH=examples/fixtures/player_camera_director.request.json ./tools/splot_step.sh

# Fala hosts Splot (when wired)
cd ../Fala && mise exec -- pixi run splot-integration
```

Takt v0.2 ships the **effector side** (`tools/takt_step.sh`). A Fala
`domain_packs/takt` vocabulary pack can live in the Fala repo later (same pattern
as `domain_packs/splot`) without coupling core takt to Fala types.
