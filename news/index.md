# Changelog

## lbugr 0.1.0

- Initial release of `lbugr`.
- Provides a wrapper around the official Python `ladybug` client using
  `reticulate`.
- Core functionality includes:
  - Connecting to a Ladybug database (`lb_connection`).
  - Executing Cypher queries (`lb_execute`).
  - Loading data from R data frames (`lb_copy_from_df`).
  - Retrieving query results as R data frames or tibbles.
- Integration with R graph libraries:
  - Direct conversion to `igraph` objects with
    [`as_igraph()`](https://wickm.github.io/lbugr/reference/as_igraph.md).
  - Direct conversion to `tidygraph` objects with
    [`as_tidygraph()`](https://wickm.github.io/lbugr/reference/as_tidygraph.md).
  - Integration with `g6R` for interactive visualization via `igraph`
    objects.
- Added vignettes for installation, usage, and graph library
  integrations.
