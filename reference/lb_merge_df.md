# Merge Data from a Data Frame into Ladybug using a Merge Query

This function is intended for merging data from an R `data.frame` into
Ladybug using a specified merge query.

## Usage

``` r
lb_merge_df(conn, df, merge_query)
```

## Arguments

- conn:

  A Ladybug connection object.

- df:

  A `data.frame` or `tibble` containing the data to merge.

- merge_query:

  A string representing the Ladybug query for merging data.

## Value

This function is called for its side effect of merging data and does not
return a value.

## See also

[Ladybug Copy from
DataFrame](https://ladybugdb.com/import/copy-from-dataframe)

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- lb_connection(":memory:")

lb_execute(conn, "CREATE NODE TABLE Person(name STRING, current_city STRING,
PRIMARY KEY (name))")
lb_execute(conn, "CREATE NODE TABLE Item(name STRING, PRIMARY KEY (name))")
lb_execute(conn, "CREATE REL TABLE PURCHASED(FROM Person TO Item)")

my_data <- data.frame(
  name = c("Alice", "Bob"),
  item = c("Book", "Pen"),
  current_city = c("New York", "London")
)

merge_statement <- "
MERGE (p:Person {name: df.name})
MERGE (i:Item {name: df.item})
MERGE (p)-[:PURCHASED]->(i)
ON MATCH SET p.current_city = df.current_city
ON CREATE SET p.current_city = df.current_city
"

lb_merge_df(conn, my_data, merge_statement)

result <- lb_execute(conn, "MATCH (p:Person)-[:PURCHASED]->(i:Item)
RETURN p.name, i.name, p.current_city")
print(as.data.frame(result))
} # }
```
