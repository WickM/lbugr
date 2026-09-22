# Build graph data + table rows from uniform query rows.

Build graph data + table rows from uniform query rows.

## Usage

``` r
rows_to_graph(rows, schema_map)
```

## Arguments

- rows:

  List of row lists (`viewer_run_query()$results`), each with `type`,
  `id`, `label`, `source`, `target` (NULL where not applicable).

- schema_map:

  Output of
  [`parse_schema()`](https://wickm.github.io/lbugr/reference/parse_schema.md)
  (rel type -\> from/to tables).

## Value

`list(nodes = <data.frame id,label,type,color>, edges = <data.frame id,source,target,rel_type>, table = <data.frame kind,type,id,label,source,target>)`.
Rows are deterministically ordered (nodes by id, edges by
(rel,source,target), table: nodes then edges by id, type colors by
sorted type) — the backend does not guarantee row order, and the g6R
layout must be reproducible.
