# Fetch the schema of a local LadybugDB connection in `/schema` shape.

Uses the catalog helpers of the installed ladybug Python driver
(`_get_node_table_names` / `_get_rel_table_names` /
`_get_node_property_names` on the Connection) plus count queries via
public Cypher. Returns the same shape the reference app's
`GET /api/v1/schema` endpoint served, so
[`parse_schema()`](https://wickm.github.io/lbugr/reference/parse_schema.md)
consumes it unchanged. Verified against a local seeded DB (plan D7).

## Usage

``` r
viewer_fetch_schema(conn)
```

## Arguments

- conn:

  A Ladybug connection object from
  [`lb_connection()`](https://wickm.github.io/lbugr/reference/lb_connection.md).

## Value

A list with `node_tables` (name, count, columns) and `rel_tables` (name,
count, connection).
