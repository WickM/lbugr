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
first_row <- lb_get_n(result, 1)
#> Error: object 'result' not found
# }
```
