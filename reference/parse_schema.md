# Parse a parsed `/schema`-shaped JSON document into nodes and rels.

Parse a parsed `/schema`-shaped JSON document into nodes and rels.

## Usage

``` r
parse_schema(schema_json)
```

## Arguments

- schema_json:

  List (parsed JSON) with `node_tables` and `rel_tables`.

## Value

`list(nodes = <named list>, rels = <named list>)` where `nodes[[name]]`
is `list(name, pk, label_cols, columns, count)` and `rels[[name]]` is
`list(name, from, to, from_pk, to_pk, count)`.
