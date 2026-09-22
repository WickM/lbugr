# Build the full-graph Cypher query for a schema map.

One `UNION` branch per node table and per rel table; every branch
returns the uniform row shape `{type, id, label, source, target}` (NULL
where not applicable). LadybugDB requires consistent column types across
UNION branches, so absent values are typed with `CAST(NULL AS STRING)`.
Syntax verified live against LadybugDB (reference app, 2026-09-11).

## Usage

``` r
generate_graph_query(schema_map)
```

## Arguments

- schema_map:

  Output of
  [`parse_schema()`](https://wickm.github.io/lbugr/reference/parse_schema.md).

## Value

A single deterministic Cypher string; branches are joined by
`"\nUNION\n"`.
