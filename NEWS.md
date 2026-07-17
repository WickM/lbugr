# lbugr 0.2.0

* **Major change**: Migrated from Python (`reticulate`) to Rust (`lbug` crate) backend.
* The Ladybug database engine is now bundled directly into the package via Rust, eliminating all external dependencies beyond R packages.
* No Python installation required. Users no longer need to install Python 3.14+ or the `ladybug` Python package.
* `check_ladybug_installation()` is now deprecated and will be removed in a future version.
* Removed `reticulate` from package dependencies.
* Added `SystemRequirements: Cargo (Rust's package manager), rustc` to DESCRIPTION.
* All exported functions maintain the same API for backward compatibility.
* Query results are now returned as data frames directly from the Rust backend.

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