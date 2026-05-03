# Get Column Data Types from a Query Result

Retrieves the data types of the columns in a Ladybug query result.

## Usage

``` r
lb_get_column_data_types(result)
```

## Arguments

- result:

  A Ladybug query result object.

## Value

A character vector of column data types.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")
lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
lb_get_column_data_types(result)
} # }
```
