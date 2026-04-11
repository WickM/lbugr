# Testing Strategy for lbugr

## Overview

This document outlines the testing strategy for the lbugr R package, which provides an interface to the Ladybug Graph Database.

## Testing Framework

- **Framework**: testthat (version 3.0.0+)
- **Test Location**: `tests/testthat/`
- **Running Tests**: `devtools::test()` or `testthat::test_local()`

## Test Levels

### 1. Unit Tests
Focus on individual functions in isolation. Tests are located in:
- `tests/testthat/test-lb.R` - Core connection/query functions
- `tests/testthat/test-install.R` - Installation checks
- `tests/testthat/test-lb_load_data.R` - Data loading functions
- `tests/testthat/test-graph.R` - Graph conversion functions

### 2. Integration Tests
Test interactions with Ladybug database:
- Database connection and disconnection
- Query execution with various Cypher queries
- Data import/export through the database

### 3. End-to-End Tests
Full workflow tests:
- Creating tables, loading data, querying results
- Graph conversion workflows (igraph, tidygraph)

## Test Categories

### Happy Path Tests
Verify standard functionality works correctly.

### Boundary Tests
- Empty results
- Single row data
- Large datasets
- Edge cases in type conversion

### Negative Tests
- Invalid table names
- Missing primary keys
- Malformed queries
- Missing Python dependencies

### Edge Cases
- NULL/NA handling
- Type coercion (factors, dates)
- Special characters in data

## Test Data

Test data files are located in `inst/testdata/`:
- `test_data.csv` - Standard CSV test data
- `test_data.json` - JSON test data
- `boundary_data.csv` - Boundary value test data

## Running Tests Locally

### Basic Test Execution
```r
# Load package and run all tests
devtools::test()

# Or use testthat directly
testthat::test_local()
```

### Run Specific Test File
```r
testthat::test_file("tests/testthat/test-lb.R")
```

### Run Tests with Coverage
```r
# Install covr if not available
install.packages("covr")

# Run tests and compute coverage
covr::package_coverage()
covr::report()
```

### Run Tests by Name Pattern
```r
testthat::test_local(filter = "lb_connection")
```

## CI/CD Pipeline

### GitHub Actions
The project uses GitHub Actions for continuous integration:
- `R-CMD-check.yaml` - Runs R CMD check on multiple R versions
- Tests run on: Ubuntu, macOS, Windows
- Python 3.9 with real_ladybug package

### CI Test Commands
```bash
# In CI, tests are run via R CMD check
R CMD check lbugr_*.tar.gz

# Or directly
R -e "devtools::test()"
```

## Test Dependencies

### R Packages (Suggests)
- `testthat` - Testing framework
- `tibble` - For tibble conversion tests
- `igraph` - For graph conversion tests
- `tidygraph` - For tidygraph conversion tests
- `arrow` - For Parquet file tests

### Python Dependencies
- `real_ladybug` - Ladybug Python client

## Coverage Criteria

- **Target**: 80%+ line coverage
- **Critical Functions**: 100% coverage
  - `lb_connection()`
  - `lb_execute()`
  - `lb_copy_from_df()`
  - `lb_create_table_from_df()`

## Flaky Test Strategy

### Test Isolation
- Each test uses in-memory database (`:memory:`)
- Temporary files are cleaned up with `on.exit()`
- No shared state between tests

### Handling External Dependencies
- Tests skip gracefully if Ladybug unavailable
- Use `skip_if_no_ladybug()` helper
- Installation tests verify Python package presence

### Retry Strategy
- Tests are designed to be deterministic
- No random data that could cause flakiness
- Explicit assertions with clear failure messages

## Best Practices

1. **Naming**: Test names follow `test_that("description", ...)`
2. **Fixtures**: Use helper functions in `helpers.R`
3. **Skipping**: Use `skip()` for optional features
4. **Assertions**: Use specific expect_* functions
5. **Cleanup**: Clean up resources in `on.exit()`

## Test File Structure

```
tests/testthat/
├── test-lb.R                    # Core tests
├── test-install.R               # Installation tests
├── test-lb_load_data.R          # Data loading tests
├── test-graph.R                 # Graph conversion tests
├── test-lb_create_table_from_df.R # Table creation tests
├── helpers.R                    # Test utilities
└── testthat.R                   # Test configuration
```

## Continuous Integration Dashboard

- GitHub Actions run on every push/PR
- Test results visible in GitHub Actions tab
- Codecov integration for coverage tracking (optional)

## Additional Testing

- **Spell Check**: `spelling::spell_check_package()`
- **Linting**: Uses lintr (configured in `.lintr`)
- **Documentation Tests**: Run examples via `devtools::run_examples()`
