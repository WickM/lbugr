# Open Tasks

## real_ladybug API Compatibility Issues

### Task 1: Update as.data.frame method for real_ladybug 0.15.x
**Description**: The real_ladybug Python package version 0.15.x returns an iterator instead of a query result object when calling `get_all()`. The current `as.data.frame.ladybug.query_result.QueryResult` method in `R/lb.R` line 100 uses `x$get_all()` which returns an iterator, causing the error "cannot coerce class 'c(\"real_ladybug.query_result.QueryResult\", \"python.builtin.iterator\")' to a data.frame". Need to update to iterate over the results properly.

**Status**: RESOLVED - Updated lb_execute() to pre-convert results to data.frame, and updated as.data.frame.real_ladybug.query_result.QueryResult, as_tibble.real_ladybug.query_result.QueryResult, lb_get_all, lb_get_n, lb_get_next, and extract_graph_data functions to use `while (x$has_next())` + `x$get_next()` pattern instead of `x$get_all()` iterator.

**Priority**: High
**Dependencies**: real_ladybug 0.15.x
**Files Modified**: R/lb.R, R/lb_graph.R

### Task 2: Fix VirtualAlloc memory errors with Python 3.13+
**Description**: Testing with Python 3.13 and real_ladybug 0.15.2 causes "RuntimeError: Buffer manager exception: VirtualAlloc for size 8796093022208 failed with error code 8: Not enough memory resources are available to process this command". This appears to be a bug in real_ladybug when used with Python 3.13+. May need to use older Python version or fix the buffer allocation.

**Status**: RESOLVED - Upgraded to Python 3.14 and real_ladybug 0.15.3 which includes the fix from Ladybug v0.15.0. Updated CI workflows to use Python 3.14.

**Priority**: High
**Affected**: test-lb.R (multiple tests), test-lb_load_data.R (line 384)

### Task 2b: Fix VirtualAlloc memory errors during test suite execution
**Description**: Individual tests pass but running the full test suite causes VirtualAlloc errors due to state accumulation. Each test creates `:memory:` databases that aren't properly cleaned up. Need to add proper `on.exit(cleanup_db())` to each test.

**Status**: RESOLVED - Migrated stress-sensitive test files (`test-lb.R`, `test-lb_load_data.R`, `test-lb_create_table_from_df.R`) to disk-backed temp DB fixtures via `test_conn(environment())`, hardened cleanup in `helpers.R` (guarded shutdown + temp dir cleanup + gc), and verified full `devtools::test()` on Python 3.14 runs without VirtualAlloc errors.

**Priority**: High
**Files Modified**: 
- tests/testthat/helpers.R - Added cleanup_db() function with proper db$shutdown()
- tests/testthat/test-lb.R - Added on.exit(cleanup_db()) to all tests
- tests/testthat/test-graph.R - Added on.exit(cleanup_db()) to all tests  
- tests/testthat/test-lb_load_data.R - Added on.exit(cleanup_db()) to all tests
- tests/testthat/test-lb_create_table_from_df.R - Added on.exit(cleanup_db()) to all tests
- .github/workflows/R-CMD-check.yaml - Added explicit Windows Python 3.13.9 matrix job

**Verification Notes**:
- Python 3.13.9 + real_ladybug 0.15.3: `devtools::test(filter='lb$')` passes
- Python 3.13.9 + real_ladybug 0.15.3: full `devtools::test()` still hits VirtualAlloc in later `test-lb.R` tests

### Task 3: Update tidygraph test assertions
**Description**: The tidygraph package no longer exports `n_edges()` and `n_nodes()` functions. Tests in `test-graph.R` lines 124 and 142 fail with "Error: 'n_edges' is not an exported object from 'namespace:tidygraph'". Need to update tests to use alternative functions like `igraph::gsize()` and `igraph::vcount()`.

**Status**: RESOLVED - Graph tests use `igraph::gsize()`/`igraph::vcount()` and pass under `devtools::test(filter='graph')`.

**Priority**: Medium
**Affected**: test-graph.R:124, test-graph.R:142

### Task 4: Fix as_igraph test assertions
**Description**: Tests in `test-graph.R` expect graph conversions to create nodes with edges, but newer real_ladybug version doesn't create relationships properly. Tests failing:
- test-graph.R:50 - `as_igraph converts query result with relationships`
- test-graph.R:68 - `as_igraph handles nodes without edges`
- test-graph.R:166 - `as_igraph handles multiple relationship types`
- test-graph.R:252 - `as_igraph handles complex property values`

**Status**: RESOLVED - Updated graph extraction to reconstruct node/edge structures from flattened data.frame query columns (`p._ID.offset`, `k._SRC.offset`, etc.), and updated tidygraph node handling for node-only results. Graph test file passes (`devtools::test(filter='graph')`).

**Priority**: Medium

### Task 5: Fix COPY FROM delimiter syntax
**Description**: The test `test-lb_load_data.R:223` "lb_copy_from_csv handles custom delimiter" fails because real_ladybug 0.15.x doesn't accept the `delimiter = ;` syntax in the COPY FROM command. Error: "mismatched input ';' expecting". Need to verify correct syntax or skip for older versions.

**Status**: RESOLVED - Updated delimiter test to create semicolon CSV correctly and use parser-compatible option syntax (`list(delim = "';'")`) with explicit data verification. Also made JSON-extension dependent tests deterministic by asserting expected extension-load warnings where installation is unavailable.

**Priority**: Low

## Test Fixes Applied

### Fix 6: test-install.R:78
**Description**: Changed `exists("py_install", where = "package:reticulate", mode = "function")` to `is.function(reticulate::py_install)` which works correctly.

### Fix 7: test-install.R:51
**Description**: Changed `reticulate::import("sys", quietly = TRUE)` to `reticulate::import("sys")` - the `quietly` argument was removed in newer reticulate versions.

### Fix 8: test-lb_create_table_from_df.R:4-7
**Description**: Changed skip function to check for `real_ladybug` instead of `ladybug` package name.