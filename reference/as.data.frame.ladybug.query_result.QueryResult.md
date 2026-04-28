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

# Convert the result to a data.frame
df <- as.data.frame(result)
#> Error: object 'result' not found
print(df)
#> function (x, df1, df2, ncp, log = FALSE) 
#> {
#>     if (missing(ncp)) 
#>         .Call(C_df, x, df1, df2, log)
#>     else .Call(C_dnf, x, df1, df2, ncp, log)
#> }
#> <bytecode: 0x55d3bf0cb3f8>
#> <environment: namespace:stats>
# }
```
