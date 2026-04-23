# Execute a Cypher Query

Submits a Cypher query to the Ladybug database for execution. This
function is used for all database operations, including schema
definition (DDL), data manipulation (DML), and querying (MATCH).

## Usage

``` r
lb_execute(conn, query)
```

## Arguments

- conn:

  A Ladybug connection object, as returned by
  [`lb_connection()`](https://wickm.github.io/lbugr/reference/lb_connection.md).

- query:

  A string containing the Cypher query to be executed.

## Value

A Python object representing the query result.

## Examples

``` r
# \donttest{
conn <- lb_connection(":memory:")
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.

# Create a node table
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
#> Error: object 'conn' not found

# Insert data
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#> Error: object 'conn' not found

# Query data
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#> Error: object 'conn' not found
# }
```
