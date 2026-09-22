# progress — lbugr

_Task board. `[ ]` open · `[x]` done + verified. One line per work item: date — scope._

## 2026-09-22

- [ ] 2026-09-22 — `graph_viewer`-Feature: Shiny-Graph-App unter `inst/graph_viewer/` + exportierte `graph_viewer(conn, …)`-Funktion; Feature-Parität zur mesh-viewer, lokal nur (kein SSO/Remote-API); Suggests + Deps-Check (Plan: `brain/plans/2026-09-22-graph-viewer.md`, approved)
- [x] 2026-09-22 — Project initialisation to new standard: create `brain/` (activeContext.md + progress.md) + add `^brain/` to `.Rbuildignore` (branch `feature/brain-init`). Verified: `R CMD build` → `brain/` excluded from tarball. Merged fast-forward to `main` + pushed (`cd39fdd`).
