# lbugr (development version)

* New `graph_viewer()`: an interactive local Shiny app (g6R graph + reactable
  table) to explore a `lb_connection()` database — node/relationship type
  filters, N-hop focus subgraph, pagination, free Cypher queries with
  graph-capable and table fallback, and CSV/Excel/JSON/PNG exports.
  Requires suggested packages: `shiny`, `bslib`, `g6R`, `reactable`,
  `openxlsx`, `jsonlite`, `rlang`.

# lbugr 0.1.0

* Initial release of `lbugr`.
* Provides a wrapper around the official Python `ladybug` client using `reticulate`.
* Core functionality includes:
    * Connecting to a Ladybug database (`lb_connection`).
    * Executing Cypher queries (`lb_execute`).
    * Loading data from R data frames (`lb_copy_from_df`).
    * Retrieving query results as R data frames or tibbles.
* Integration with R graph libraries:
    * Direct conversion to `igraph` objects with `as_igraph()`.
    * Direct conversion to `tidygraph` objects with `as_tidygraph()`.
    * Integration with `g6R` for interactive visualization via `igraph` objects.
* Added vignettes for installation, usage, and graph library integrations.