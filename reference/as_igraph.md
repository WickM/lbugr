# Convert a Ladybug Query Result to an igraph Object

Converts a Ladybug query result into an `igraph` graph object.

## Usage

``` r
as_igraph(query_result)
```

## Arguments

- query_result:

  A `ladybug_query_result` object from
  [`lb_execute()`](https://wickm.github.io/lbugr/reference/lb_execute.md)
  that contains a graph.

## Value

An `igraph` object.

## Details

This function takes a `ladybug_query_result` object and extracts nodes
and edges directly from the query results, then constructs an `igraph`
object. It is the final step in the `lb_execute -> as_igraph` workflow.

## Examples

``` r
if (FALSE) { # \dontrun{
if (requireNamespace("igraph", quietly = TRUE)) {
  conn <- lb_connection(":memory:")
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING,
  PRIMARY KEY (name))")
  lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
  lb_execute(conn, "CREATE (p:Person {name: 'Alice'}),
  (q:Person {name: 'Bob'})")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE
                                                    a.name='Alice' AND
                                                    b.name='Bob'
                                                    CREATE (a)-[:Knows]->(b)"
)

  res <- lb_execute(conn, "MATCH (p:Person)-[k:Knows]->(q:Person)
  RETURN p, k, q")
  g <- as_igraph(res)
  print(g)
  rm(conn, res, g)
}
} # }
```
