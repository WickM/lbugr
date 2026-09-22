# activeContext — lbugr

_Last updated: 2026-09-22. Current live state of the project — source of truth for "where are we right now". Durable lessons/decisions → Cognee (`projekt-lbugr`), not here._

## Project

- R package **lbugr** (v0.1.1) — R interface to the [Ladybug Graph Database](https://ladybugdb.com/).
- Architecture: R → `reticulate` → Python `ladybug` client. Ladybug is a fork of the no-longer-maintained Kuzu; lbugr is the successor of kuzuR.
- **Python 3.14+ required** (kuzu VirtualAlloc memory fix in the underlying engine).
- Published on CRAN (`install.packages("lbugr")`); pkgdown site; testthat (3e) suite; codecov CI.

## Current State (2026-09-22)

- `main` @ `cd39fdd` (1 commit ahead of tag v0.1.1), clean tree. Last commit: `chore: initialise brain/ (activeContext + progress), exclude from R build`.
- **Active:** `feature/graph-viewer` @ Phases 2+3 committed — Shiny-Graph-Viewer (`inst/graph_viewer/`) + exportierte `graph_viewer(conn, …)`; Tests grün, R CMD check ohne neue Errors/Warnings (nur 2 `--no-build-vignettes`-Artefakte), Tarball verifiziert (DC8). **Offen:** DC9 manueller Browser-Smoke mit User + Merge-Entscheidung.

## Open Branches / Pending Decisions

| Branch | Last activity | Content | Status |
|---|---|---|---|
| `feature/graph-viewer` | 2026-09-22 (2 commits ahead) | Interactive Shiny graph viewer: `graph_viewer(conn)` (g6R + reactable + bslib), local LadybugDB only | Unmerged — awaiting manual smoke (DC9) + user merge decision |
| `feature/json-extension-check` | 2026-08-25 (1 commit ahead) | Gracefully handle missing Ladybug JSON extension | Unmerged |
| `rust-backend` | 2026-07-17 (2 commits ahead) | **Strategic:** migrate backend from Python/reticulate to Rust (`lbug` crate) | Unmerged — decision pending: keep the reticulate bridge or migrate? |

## Repo Gotchas

- `README.md` is **generated from `README.Rmd`** — edit the `.Rmd`, never the `.md`.
- Agent files: `Agent.md` = local project spec (build-excluded, not gitignored); `.kilo/` gitignored. `AGENTS.md` and `docs/` are gitignored + build-ignored → local-only, do not commit.
- `brain/` **is committed** and excluded from the R build via `.Rbuildignore`.
- Dev loop: `devtools::load_all()` / `devtools::test()` / `devtools::document()` / `devtools::check()` — NAMESPACE is roxygen2-generated, never edit by hand.
- Tests: `tests/testthat/`; live-QA-style gating pattern (env var, skipped by default) established in sibling repos — check `tests/testthat/helpers.R` before adding new tests.
