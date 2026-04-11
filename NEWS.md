# lbugr 0.1.0

* Initial release of `lbugr`.
* Provides a wrapper around the official Python `real_ladybug` client using `reticulate`.
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

# lbugr 0.1.1 (Development)

* **Python version support**: Now supports Python 3.14 (was 3.9). The VirtualAlloc memory error with Python 3.13+ is resolved by using real_ladybug 0.15.0+ which includes the fix from the Ladybug database.
* Updated CI to use Python 3.14, plus an explicit Windows job for Python 3.13.9 compatibility checks.