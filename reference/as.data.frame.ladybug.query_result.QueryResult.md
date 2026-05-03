# Convert a Ladybug Query Result to a Data Frame

Provides an S3 method to seamlessly convert a Ladybug query result
object into a standard R `data.frame`.

## Usage

``` r
# S3 method for class 'ladybug.query_result.QueryResult'
as.data.frame(x, ...)
```

## Arguments

- x:

  A Ladybug query result object.

- ...:

  Additional arguments passed to `as.data.frame`.

## Value

An R `data.frame` containing the query results.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")

# Convert the result to a data.frame
df <- as.data.frame(result)
print(df)
} # }
```
