# Retrieve the First N Rows from a Query Result

Fetches the first `n` rows from a Ladybug query result.

## Usage

``` r
lb_get_n(result, n)
```

## Arguments

- result:

  A Ladybug query result object.

- n:

  The number of rows to retrieve.

## Value

A list of the first `n` rows.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
lb_execute(conn, "CREATE (:User {name: 'Bob', age: 30})")
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
first_row <- lb_get_n(result, 1)
} # }
```
