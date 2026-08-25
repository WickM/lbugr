# lbugr (development version)

* `lb_copy_from_json()` now detects whether the Ladybug `json` extension can
  be installed and loaded. If not, it emits an informative `warning()` and
  returns invisibly instead of failing with a Cypher error. This makes
  loading JSON usable on deployments where server-side extensions are
  disabled.

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