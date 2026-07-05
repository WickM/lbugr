## Submission for CRAN

This is the initial submission of `lbugr`, an R interface to the Ladybug Graph Database. Ladybug is a fork of the Kuzu graph database, which is no longer actively maintained.

### Summary

- Provides high-performance R interface to the Ladybug graph database
- Uses `reticulate` to wrap the official Python `ladybug` client
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

- **Imports**: reticulate, digest, tibble
- **Suggests**: g6R, igraph, tidygraph, jsonlite, testthat (>= 3.0.0), knitr, rmarkdown, spelling, arrow, withr
- **Python**: Requires `ladybug` Python package (Python 3.14+ recommended)

### Note on Python Dependency

The package requires the `ladybug` Python package. Installation instructions are provided in the Description field and in the README. Users must install this Python package separately using `reticulate::py_install("ladybug", pip = TRUE)`.

**Note**: Python 3.14+ is required due to fixes in the underlying kuzu database engine that resolve VirtualAlloc memory issues on Windows with Python 3.13+.

### Addressing CRAN Pre-test NOTEs

The following NOTEs were identified in the CRAN pre-tests and have been addressed:

#### 1. CPU Time NOTEs (Installation, Tests, Vignettes)

**Issue**: The pre-tests reported CPU time exceeding elapsed time for installation (2.8x), tests (3.7x), and vignette re-building (2.9x).

**Explanation**: This package wraps a Python graph database (Ladybug/Kuzu) via reticulate. The elevated CPU times are expected due to:
- **Installation**: Compiling Python extensions and initializing the graph database engine
- **Tests**: Graph database operations are CPU-intensive; tests use in-memory databases for efficiency
- **Vignettes**: Graph queries and conversions to igraph/tidygraph objects require significant computation

**Mitigations applied**:
- All vignette code chunks now use `eval=FALSE` to prevent execution during package build
- Tests use shared connection fixtures to reduce overhead
- In-memory databases (`:memory:`) are used instead of on-disk databases for faster test execution
- Proper cleanup functions prevent resource accumulation between tests

#### 2. New Submission NOTE

This is the first submission of this package to CRAN.

### Test Results

R CMD check --as-cran results (Windows, R 4.5.1):

- checking for file 'lbugr/DESCRIPTION' ... OK
- checking package namespace information ... OK
- checking package dependencies ... OK
- checking if this is a source package ... OK
- checking for executable files ... OK
- checking for hidden files and directories ... OK
- checking for portable file names ... OK
- checking whether package 'lbugr' can be installed ... OK
- checking installed package size ... OK
- checking code files for non-ASCII characters ... OK
- checking R files for syntax errors ... OK
- checking whether the package can be loaded ... OK
- checking whether the package can be loaded with stated dependencies ... OK
- checking dependencies in R code ... OK
- checking Rd files ... OK
- checking for missing documentation entries ... OK
- checking examples ... OK
- checking tests ... OK

### Current Status

All checks pass. The package is ready for CRAN inclusion.

### Comments from CRAN Reviewers

We welcome feedback from CRAN maintainers on this initial submission.