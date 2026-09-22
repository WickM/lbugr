# Execute a Cypher query on a local connection and return uniform rows.

Shaped like the reference app's `run_query()`: `results` is a list of
row lists (column names as names), `row_count` the number of rows. Node
and relationship values are flattened into their property fields
(`n.name`, `r._LABEL`, ...), which is what
[`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md)
/
[`rows_to_df()`](https://wickm.github.io/lbugr/reference/rows_to_df.md)
consume via the uniform `{type, id, label, source, target}` shape
produced by
[`generate_graph_query()`](https://wickm.github.io/lbugr/reference/generate_graph_query.md).

## Usage

``` r
viewer_run_query(conn, query)
```

## Arguments

- conn:

  A Ladybug connection from
  [`lb_connection()`](https://wickm.github.io/lbugr/reference/lb_connection.md).

- query:

  A single Cypher query string (read-only; the blocklist in
  [`viewer_check_query()`](https://wickm.github.io/lbugr/reference/viewer_check_query.md)
  is applied first).

## Value

`list(results = <list of row lists>, row_count = <integer>)`.
