## Submission for CRAN

This is the initial submission of `lbugr`, an R interface to the Ladybug Graph Database. Ladybug is a fork of the Kuzu graph database, which is no longer actively maintained.

### Summary

- Provides high-performance R interface to the Ladybug graph database
- Uses `reticulate` to wrap the official Python `real_ladybug` client
- Maintains API compatibility with the predecessor package `kuzuR`
- All function names use `lb_` prefix (Ladybug) to avoid conflicts

### New Package Features

- `lb_connection()` - Create/open Ladybug database connection
- `lb_execute()` - Execute Cypher queries
- `lb_copy_from_df()` - Load R data frames into Ladybug
- `lb_create_table_from_df()` - Create tables from R data frames
- `lb_copy_from_csv()`, `lb_copy_from_json()`, `lb_copy_from_parquet()` - File import
- `lb_get_*` functions - Query result inspection
- `as_igraph()`, `as_tidygraph()` - Graph conversion
- Integration with `g6R` for visualization

### Dependencies

- **Imports**: reticulate, igraph, tibble, tidygraph, digest
- **Suggests**: g6R, jsonlite, testthat (>= 3.0.0), knitr, rmarkdown, spelling, arrow
- **Python**: Requires `real_ladybug` Python package

### Note on Python Dependency

The package requires the `real_ladybug` Python package. Installation instructions are provided in the Description field and in the README. Users must install this Python package separately using `reticulate::py_install("real_ladybug", pip = TRUE)`.

### Test Results

R CMD check results will be available after running checks. All tests are designed to skip gracefully if the Python package is not available.
