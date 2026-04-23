# Load Data from a Parquet File into a Ladybug Table

Loads data from a Parquet file into a specified table in the Ladybug
database.

## Usage

``` r
lb_copy_from_parquet(conn, file_path, table_name)
```

## Arguments

- conn:

  A Ladybug connection object.

- file_path:

  A string specifying the path to the Parquet file.

- table_name:

  A string specifying the name of the destination table in Ladybug.

## Value

This function is called for its side effect of loading data and does not
return a value.

## See also

[Ladybug Parquet Import](https://ladybugdb.com/import/parquet)

## Examples

``` r
# \donttest{
  if (requireNamespace("arrow", quietly = TRUE)) {
    conn <- lb_connection(":memory:")
    lb_execute(conn, "CREATE NODE TABLE Country(name STRING, code STRING,
    PRIMARY KEY (name))")

    # Create a temporary Parquet file
    parquet_file <- tempfile(fileext = ".parquet")
    country_df <- data.frame(name = c("USA", "Canada"), code = c("US", "CA"))
    arrow::write_parquet(country_df, parquet_file)

    # Load data from Parquet
    lb_copy_from_parquet(conn, parquet_file, "Country")

    # Verify the data
    result <- lb_execute(conn, "MATCH (c:Country) RETURN c.name, c.code")
    print(as.data.frame(result))

    # Clean up the temporary file
    unlink(parquet_file)
  }
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.
# }
```
