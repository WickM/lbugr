# Convert a Ladybug Query Result to a tidygraph Object

Converts a Ladybug query result into a `tidygraph` `tbl_graph` object.

## Usage

``` r
as_tidygraph(query_result)
```

## Arguments

- query_result:

  A `ladybug_query_result` object from
  [`lb_execute()`](https://wickm.github.io/lbugr/reference/lb_execute.md)
  that contains a graph.

## Value

A `tbl_graph` object.

## Examples

``` r
# \donttest{
if (requireNamespace("tidygraph", quietly = TRUE)) {
  conn <- lb_connection(":memory:")
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING,
  PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (p:Person {name: 'Alice'})")
  res <- lb_execute(conn, "MATCH (p:Person) RETURN p")
  g_tidy <- as_tidygraph(res)
  print(g_tidy)
  rm(conn, res, g_tidy)
}
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.
# }
```
