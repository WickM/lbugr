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
# \donttest{
conn <- lb_connection(":memory:")
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
#> Error: object 'conn' not found
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#> Error: object 'conn' not found
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#> Error: object 'conn' not found
all_results <- lb_get_all(result)
#> Error: object 'result' not found
# }
```
