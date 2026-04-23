# Package index

## Core Ladybug Connection and Querying

- [`lb_connection()`](https://wickm.github.io/lbugr/reference/lb_connection.md)
  : Create a Connection to a Ladybug Database
- [`lb_execute()`](https://wickm.github.io/lbugr/reference/lb_execute.md)
  : Execute a Cypher Query
- [`lb_get_all()`](https://wickm.github.io/lbugr/reference/lb_get_all.md)
  : Retrieve All Rows from a Query Result
- [`lb_get_n()`](https://wickm.github.io/lbugr/reference/lb_get_n.md) :
  Retrieve the First N Rows from a Query Result
- [`lb_get_next()`](https://wickm.github.io/lbugr/reference/lb_get_next.md)
  : Retrieve the Next Row from a Query Result
- [`lb_get_column_names()`](https://wickm.github.io/lbugr/reference/lb_get_column_names.md)
  : Get Column Names from a Query Result
- [`lb_get_column_data_types()`](https://wickm.github.io/lbugr/reference/lb_get_column_data_types.md)
  : Get Column Data Types from a Query Result
- [`lb_get_schema()`](https://wickm.github.io/lbugr/reference/lb_get_schema.md)
  : Get Schema from a Query Result

## Data Loading

- [`lb_copy_from_csv()`](https://wickm.github.io/lbugr/reference/lb_copy_from_csv.md)
  : Load Data from a CSV File into a Ladybug Table
- [`as.data.frame(`*`<real_ladybug.query_result.QueryResult>`*`)`](https://wickm.github.io/lbugr/reference/as.data.frame.real_ladybug.query_result.QueryResult.md)
  : Convert a Ladybug Query Result to a Data Frame
- [`as_tibble(`*`<real_ladybug.query_result.QueryResult>`*`)`](https://wickm.github.io/lbugr/reference/as_tibble.real_ladybug.query_result.QueryResult.md)
  : Convert a Ladybug Query Result to a Tibble
- [`lb_copy_from_df()`](https://wickm.github.io/lbugr/reference/lb_copy_from_df.md)
  : Load Data from a Data Frame or Tibble into a Ladybug Table
- [`lb_create_table_from_df()`](https://wickm.github.io/lbugr/reference/lb_create_table_from_df.md)
  : Create a Ladybug Table from a Data Frame
- [`lb_copy_from_json()`](https://wickm.github.io/lbugr/reference/lb_copy_from_json.md)
  : Load Data from a JSON File into a Ladybug Table
- [`lb_copy_from_parquet()`](https://wickm.github.io/lbugr/reference/lb_copy_from_parquet.md)
  : Load Data from a Parquet File into a Ladybug Table
- [`lb_merge_df()`](https://wickm.github.io/lbugr/reference/lb_merge_df.md)
  : Merge Data from a Data Frame into Ladybug using a Merge Query

## Graph Integrations

- [`as_igraph()`](https://wickm.github.io/lbugr/reference/as_igraph.md)
  : Convert a Ladybug Query Result to an igraph Object
- [`as_tidygraph()`](https://wickm.github.io/lbugr/reference/as_tidygraph.md)
  : Convert a Ladybug Query Result to a tidygraph Object

## Installation

- [`check_ladybug_installation()`](https://wickm.github.io/lbugr/reference/check_ladybug_installation.md)
  : Check for Ladybug Python Dependencies
