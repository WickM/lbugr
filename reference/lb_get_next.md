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
# \donttest{
conn <- lb_connection(":memory:")
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
#> Error: object 'conn' not found
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#> Error: object 'conn' not found
lb_execute(conn, "CREATE (:User {name: 'Bob', age: 30})")
#> Error: object 'conn' not found
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#> Error: object 'conn' not found
row1 <- lb_get_next(result)
#> Error: object 'result' not found
row2 <- lb_get_next(result)
#> Error: object 'result' not found
# }
```
