# Convert a Ladybug Query Result to a Tibble

Provides an S3 method to convert a Ladybug query result object into a
`tibble`. This requires the `tibble` package to be installed.

## Usage

``` r
# S3 method for class 'ladybug.query_result.QueryResult'
as_tibble(x, ...)
```

## Arguments

- x:

  A Ladybug query result object.

- ...:

  Additional arguments passed to `as_tibble`.

## Value

A `tibble` containing the query results.

## Examples

``` r
# \donttest{
if (requireNamespace("tibble", quietly = TRUE)) {
  conn <- lb_connection(":memory:")
  lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
  PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
  result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")

  # Convert the result to a tibble
  tbl <- tibble::as_tibble(result)
  print(tbl)
}
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.
# }
```
