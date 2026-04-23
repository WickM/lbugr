# Load Data from a JSON File into a Ladybug Table

Loads data from a JSON file into a specified table in the Ladybug
database. This function also ensures the JSON extension is loaded and
available.

## Usage

``` r
lb_copy_from_json(conn, file_path, table_name)
```

## Arguments

- conn:

  A Ladybug connection object.

- file_path:

  A string specifying the path to the JSON file.

- table_name:

  A string specifying the name of the destination table in Ladybug.

## Value

This function is called for its side effect of loading data and does not
return a value.

## See also

[Ladybug JSON Import](https://ladybugdb.com/import/copy-from-json),
[Ladybug JSON Extension](https://ladybugdb.com/extensions/json)

## Examples

``` r
# \donttest{
  conn <- lb_connection(":memory:")
#> Error in py_run_string_impl(code, local, convert): AttributeError: 'NoneType' object has no attribute 'Database'
#> Run `reticulate::py_last_error()` for details.
  lb_execute(conn, "CREATE NODE TABLE Product(id INT64, name STRING,
  PRIMARY KEY (id))")
#> Error: object 'conn' not found

  # Create a temporary JSON file
  json_file <- tempfile(fileext = ".json")
  json_data <- '[{"id": 1, "name": "Laptop"}, {"id": 2, "name": "Mouse"}]'
  writeLines(json_data, json_file)

  # Load data from JSON
  lb_copy_from_json(conn, json_file, "Product")
#> Warning: Could not install or load JSON extension. Please check your internet connection and Ladybug setup.
#> Warning: restarting interrupted promise evaluation
#> Error: object 'conn' not found

  # Verify the data
  result <- lb_execute(conn, "MATCH (p:Product) RETURN p.id, p.name")
#> Error: object 'conn' not found
  print(as.data.frame(result))
#> Error: object 'result' not found

  # Clean up the temporary file
  unlink(json_file)
# }
```
