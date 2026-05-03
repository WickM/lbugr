# Retrieve All Rows from a Query Result

Fetches all rows from a Ladybug query result and returns them as a list
of lists.

## Usage

``` r
lb_get_all(result)
```

## Arguments

- result:

  A Ladybug query result object.

## Value

A list where each element is a list representing a row of results.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
all_results <- lb_get_all(result)
} # }
```
