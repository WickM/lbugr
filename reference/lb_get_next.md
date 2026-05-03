# Retrieve the Next Row from a Query Result

Fetches the next available row from a Ladybug query result. This
function can be called repeatedly to iterate through results one by one.

## Usage

``` r
lb_get_next(result)
```

## Arguments

- result:

  A Ladybug query result object.

## Value

A list representing the next row, or `NULL` if no more rows are
available.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
lb_execute(conn, "CREATE (:User {name: 'Bob', age: 30})")
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
row1 <- lb_get_next(result)
row2 <- lb_get_next(result)
} # }
```
