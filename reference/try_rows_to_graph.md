# Try to interpret uniform query rows as a graph model (or not).

A free query is graph-capable only if its rows follow the uniform
`{type, id, label, source, target}` shape and use rel types present in
the schema.
[`rows_to_graph()`](https://wickm.github.io/lbugr/reference/rows_to_graph.md)
aborts on anything else (scalar rows such as `count`, an unknown rel
type, or a mixed node/edge row); this wrapper turns that abort into a
value so the view can fall back to a plain result table instead of
erroring the whole query run.

## Usage

``` r
try_rows_to_graph(rows, schema_map)
```

## Arguments

- rows:

  List of row lists (`viewer_run_query()$results`).

- schema_map:

  Output of
  [`parse_schema()`](https://wickm.github.io/lbugr/reference/parse_schema.md).

## Value

`list(ok = TRUE, model = rows_to_graph(rows, schema_map))` on success,
otherwise `list(ok = FALSE, reason = <character>)`.
