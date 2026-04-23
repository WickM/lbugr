# Create a Connection to a Ladybug Database

Establishes a connection to a Ladybug database. If the database does not
exist at the specified path, it will be created. This function combines
the database initialization and connection steps into a single call.

## Usage

``` r
lb_connection(path)
```

## Arguments

- path:

  A string specifying the file path for the database. For an in-memory
  database, use `":memory:"`.

## Value

A Python object representing the connection to the Ladybug database.

## Examples

``` r
# \donttest{
# Create an in-memory database and connection
conn <- lb_connection(":memory:")
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.

# Create or connect to an on-disk database
temp_db_dir <- file.path(tempdir(), "ladybug_disk_example_db")
db_path <- file.path(temp_db_dir, "ladybug_db")
dir.create(temp_db_dir, recursive = TRUE, showWarnings = FALSE)

# Establish connection
conn_disk <- lb_connection(db_path)
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.

# Ensure the database is shut down and removed on exit
on.exit({
  db <- attr(conn_disk, "lbugr_db")
  if (!is.null(db)) {
    db$shutdown()
  }
  unlink(temp_db_dir, recursive = TRUE)
})
#> Error: object 'conn_disk' not found
# }
```
