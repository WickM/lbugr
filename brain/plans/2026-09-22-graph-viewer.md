# Graph Viewer (graph_viewer) — Deep Plan

Date: 2026-09-22 · Branch: `feature/graph-viewer` · Status: **CLOSED** (2026-09-22) — Phases 0–4 done + verified (check/build/tarball/tests), DC9 via User-Approval; fast-forward merged nach `main` + gepusht.
Reference app: `C:\ungesichert\developR\analytics-governance-metadata-mesh-viewer-rshiny-at`

## 1. Objective (one sentence)

`graph_viewer(conn, ...)` in lbugr: Shiny-App (g6R + reactable + bslib) unter `inst/graph_viewer/`, die eine **lokale** LadybugDB-Verbindung interaktiv exploriert — Feature-Parität zur metadata-mesh-viewer, **kein** Remote-API, **kein SSO** (lokal nur, user-confirmed).

## 2. Done Criteria (verifiably)

- **DC1** `viewer_fetch_schema(conn)` liefert die /schema-Shape (node_tables: name/count/columns{name,type,primary key}; rel_tables: name/count/connection{from,to,from_pk,to_pk}) für eine lokale Test-DB
- **DC2** Roundtrip-Test: fetch_schema → parse_schema → generate_graph_query → viewer_run_query → rows_to_graph → korrekte Nodes/Edges
- **DC3** Portierte Pure-Logic-Tests grün (cypher_gen Golden, schema_map Fixtures, graph_model, context, ego, exports)
- **DC4** Write-Keyword-Blocklist: CREATE/DROP/…-Query wirft "blocked keyword"-Error
- **DC5** `graph_viewer()` mit fehlendem Suggest → `stop()` mit fehlenden Paketen + `install.packages()`-Hint
- **DC6** `create_graph_viewer_app(conn)` liefert ein `shiny.appobj` ohne Launch
- **DC7** `devtools::document()` clean · `devtools::test()` grün · `devtools::check()` kein neuer Error/Warning
- **DC8** `R CMD build`-Tarball enthält `inst/graph_viewer/`, exkludiert `brain/`
- **DC9** Manueller Smoke (mit User): seeded DB → Selection→Context-Dimm, Ego-Hops, Free-Query (Graph + Table-Fallback), Exporte, Reset
- **DC10** DESCRIPTION (Suggests + `0.1.1.9000`) · NEWS.md · brain-Sync · Cognee `[SESSION LOG]`

## 3. Out of Scope

- SSO/Auth (lokal nur — user-confirmed) · Remote-API-Modus · Multi-User/Deployment
- Vignette/README-Updates (Folge-Kandidat) · Playwright-e2e · Mesh-Domain-Spezifika (4-Klang-Tabellennamen)
- rhino/box/sass/config.yml/renv (Corporate-Scaffolding)
## 4. Ansatz (approved: Option A)

| | **A: Logik in R/, UI in inst/ (approved)** | B: self-contained inst/-App | C: MVP-Subset |
|---|---|---|---|
| Testbarkeit | Package-testthat, roxygen, R CMD check | manuelles Sourcing, keine Coverage | ✓ |
| Wiederverwendbarkeit | Converter-API-Familie (`as_igraph` …) | ✗ | ✗ |
| Feature-Parität | voll | voll | ✗ (verletzt Anforderung) |
| Aufwand | M | M | S |

### Decision Log (vorregistriert)
- **D1** Logik = interne Funktionen in `R/` (`@keywords internal`); UI + Glue in `inst/graph_viewer/`. Nur `graph_viewer()` exportiert.
- **D2** Client-side Blocklist `c(DROP, DELETE, CREATE, ALTER, DETACH, MERGE)`, word-boundary-Regex (`\b…\b`, case-insensitive) — die Mesh-App ließ das Backend enforceen; hier gibt es kein Backend. Word-Boundary ist Pflicht: Darf `created_at` (Property) NICHT matchen.
- **D3** Plan-Konvention: Single-File `brain/plans/YYYY-MM-DD-<slug>.md` (User-Decision 2026-08-20).
- **D4** Kein dplyr (verifiziert: nicht in Module/Logik verwendet).
- **D5** UI-Texte Englisch (CRAN-Konvention).
- **D6** In-prozess-Shiny-Server; `conn` via Closure (kein 2. Prozess → kein DB-Lock).
- **D7** [Phase 0 ✅] Schema-Discovery-Rezept (verifiziert gegen lokal geseedete DB, 2026-09-22): Ladybug hat **keine** `SHOW`-Befehle, kein `CALL show_table_info`, kein öffentlicher Catalog-Methoden-Access — aber die **privaten Connection-Helper** liefern alles, inkl. leerer Tabellen: `conn$`_get_node_table_names`()` → `c("Person","EmptyT")`; `conn$`_get_rel_table_names`()` → `list(list(name="Knows", src="Person", dst="Person"))`; `conn$`_get_node_property_names`(table)` → `list(name = list(type="STRING", dimension=0, is_primary_key=TRUE), …)` (echte Kuzu-Typen). Counts via Public Cypher: `MATCH (n:T) RETURN count(n) AS cnt`. **Kein Cypher-Fallback** (YAGNI): bei API-Änderung klaren Error mit Upgrade-Hint. R-Parser-Kuriosum: `conn$`_name`()` braucht Backticks (`conn$_name` ist ein Parse-Error).
- **D9** [Phase 0] `query_result_to_df()` (lb.R) bricht bei OPTIONAL-MATCH-Results mit gemischten Spalten ("numbers of columns of arguments do not match" via `rbind`) — blockiert die Full-Graph-Query. Fix: Spalten-Union mit NA-Fill (Kern-Bugfix, nur für aktuell fehlerhafte Fälle → kein Verhalten für funktionierende Cases).
- **D8** `lb_execute(conn, q)` liefert bereits ein `data.frame` (nicht rohes Python-Result) → `viewer_run_query()` baut `results` als list-of-row-lists aus dem df; node/rel-Zeilen brauchen Adapter (`_label`→`label`, `_src`/`_dst`→from/to, rel `_label`→`type`), Shape wird im Spike verifiziert.

## 5. Suggests (neu)

`shiny`, `bslib`, `reactable`, `openxlsx`, `rlang` (`g6R`, `jsonlite` bereits da). Alle auf CRAN. Kein neues Import.

## 6. Phasen

### Phase 0 — Spike: lokale Schema-Discovery (**GATE: kein Phase-1-Code ohne Rezept**)
- Seed: `Person(name PK, age)`, `City(name PK, population)`, `Knows(Person→Person)`, `LivesIn(Person→City)`
- Kandidaten: `SHOW TABLES` · Spalten: `SHOW PROPERTY TABLES <t>` / `MATCH (n:T) RETURN n` + `names()` · Rels: `SHOW REL TABLES` / `MATCH ()-[r]->()` + `type(r)` · Counts: `MATCH (n:T) RETURN count(n)`
- funktionierendes Rezept in D7 loggen → Basis für `viewer_fetch_schema()`
- **Totalausfall → STOP:** `FAILED_APPROACH` in Cognee + Alternativen ansprechen

### Phase 1 — Logik in `R/` (TDD: Tests erst, dann Port)
| Datei | Inhalt |
|---|---|
| `R/graph_viewer_schema.R` | `parse_schema()` (1:1-Port) + `viewer_fetch_schema(conn)` (Spike-Rezept) |
| `R/graph_viewer_query.R` | `viewer_run_query(conn, q)` → `list(results = <list of row lists>, row_count)` via `lb_execute` + Row-Normalisierung (D8); `viewer_check_query()` (Blocklist) |
| `R/graph_viewer_model.R` | `rows_to_graph`, `rows_to_df`, `try_rows_to_graph`, `cap_graph` (1:1-Port) |
| `R/graph_viewer_context.R` | `context_state`, `ego_subgraph` (1:1-Port) |
| `R/graph_viewer_exports.R` | `table_to_csv`, `rows_to_json`, `df_to_xlsx` (1:1-Port) |
| `R/graph_viewer.R` | `graph_viewer()` (exportiert) + `check_app_deps()` |

- Tests: Referenz-Suite portieren (`test-cypher_gen`, `test-schema_map`, `test-graph_model`, `test-context`, `test-neighborhood`, `test-exports` + `fixtures/`) — erst rot, dann grün
- DB-Tests: `skip_if_no_ladybug` + `test_conn` + extended setup (4 Tabellen, 2 Rel-Typen)

### Phase 2 — App in `inst/graph_viewer/`
- `view/graph_module.R`: ~960-Zeilen-Port: `box::use`→direkte Refs, `config::get`→Parameter, `run_query`/`fetch_schema`→lbugr-intern; **g6R-Canvas-Leak-Guard + Click-Bridge 1:1** (verifizierter Code, inkl. Shiny-1.12-Kenntnis)
- `app.R`: `create_graph_viewer_app(conn, page_size = 300L, load_step = 300L)` → `shinyApp`
- `app.min.css`: prebuilt-CSS der Referenz kopieren (kein sass)
- App-Code wird via `sys.source` in `new.env(parent = asNamespace("lbugr"))` geladen → Intern-Access ohne `:::`

### Phase 3 — Entry + Packaging
- `graph_viewer(conn, port = NULL, host = "127.0.0.1", launch_browser = interactive(), page_size = 300L, load_step = 300L, ...)`: conn-Validierung → `check_app_deps()` → App-Env sourcen → `shiny::runApp(app, …)`
- DESCRIPTION: Suggests += 5 Pakete, Version `0.1.1.9000` · NEWS.md-Eintrag · roxygen + `devtools::document()`

### Phase 4 — Verify
- `devtools::document()` / `test()` / `check()` · `R CMD build`-Tarball-Inspektion (DC8) · manueller Smoke mit User (DC9)

### Phase 5 — Closeout
- Plan-Status finalisieren · `progress.md` `[x]` · `activeContext.md` sync · Cognee `[SESSION LOG]` + Lessons (`projekt-lbugr`) · Commits · Merge-Handover an User

## 7. Risiken

- **R1** Schema-Discovery-Syntax (Ladybug vs. Kuzu) → Phase-0-GATE + Fallback-Ladder
- **R2** g6R-Canvas-Leak mit Shiny 1.12 → verifizierten Guard 1:1 porten
- **R3** In-prozess Python/Shiny → lokal Single-User, synchroner Server (Mesh-App hat das g6R+Shiny-Pattern belegt)
