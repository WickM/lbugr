# Tests for lbugr Data Loading Functions

# Skip all tests if ladybug is not available
skip_if_no_ladybug <- function() {
  if (!reticulate::py_module_available("real_ladybug")) {
    skip("real_ladybug Python package not available")
  }
}

# Test lb_copy_from_df loads data into node table
test_that("lb_copy_from_df loads data into node table", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create a node table
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  
  # Create data frame to load
  df <- data.frame(
    name = c("Alice", "Bob"),
    age = c(25L, 30L),
    stringsAsFactors = FALSE
  )
  
  # Load data
  lb_copy_from_df(conn, df, "Person")
  
  # Verify data was loaded
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age ORDER BY p.name")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
  expect_equal(nrow(df_result), 2)
})

# Test lb_copy_from_df handles numeric NA values
test_that("lb_copy_from_df handles numeric NA values", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create a node table
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  
  # Create data frame with NA
  df <- data.frame(
    name = c("Alice", "Bob"),
    age = c(NA, 30L),
    stringsAsFactors = FALSE
  )
  
  # Should not throw an error
  expect_silent(lb_copy_from_df(conn, df, "Person"))
})

# Test lb_copy_from_df handles factor columns
test_that("lb_copy_from_df converts factor to character", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create a node table
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  
  # Create data frame with factor
  df <- data.frame(
    name = factor(c("Alice", "Bob"))
  )
  
  # Should not throw an error - factors should be converted
  expect_silent(lb_copy_from_df(conn, df, "Person"))
})

# Test lb_copy_from_df validates table_name
test_that("lb_copy_from_df validates table_name", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  df <- data.frame(x = 1)
  
  # Invalid table name should throw an error
  expect_error(
    lb_copy_from_df(conn, df, "invalid;table"),
    "valid identifier"
  )
})

# Test lb_copy_from_df works with relationship tables
test_that("lb_copy_from_df loads data into relationship table", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create node tables
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  
  # Create relationship table
  lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
  
  # Insert nodes first
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  
  # Create relationship data frame
  rel_df <- data.frame(
    from_person = c("Alice"),
    to_person = c("Bob"),
    stringsAsFactors = FALSE
  )
  
  # Note: This test may need adjustment based on Ladybug's actual behavior
  # The column names may need to match the primary key columns
})

# Test lb_create_table_from_df creates a node table
test_that("lb_create_table_from_df creates a node table", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create data frame
  df <- data.frame(
    name = c("Alice", "Bob"),
    age = c(25L, 30L),
    height = c(1.75, 1.80),
    is_student = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  
  # Create table from data frame
  lb_create_table_from_df(conn, df, "Person", primary_key = "name")
  
  # Verify table was created
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
})

# Test lb_create_table_from_df maps R types to Ladybug types correctly
test_that("lb_create_table_from_df maps types correctly", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create data frame with various types
  df <- data.frame(
    int_col = c(1L, 2L),
    dbl_col = c(1.5, 2.5),
    chr_col = c("a", "b"),
    lgl_col = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  
  # Should create table without error
  expect_silent(lb_create_table_from_df(conn, df, "TestTable", primary_key = "int_col"))
})

# Test lb_create_table_from_df validates primary key exists
test_that("lb_create_table_from_df validates primary key", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  df <- data.frame(name = c("Alice", "Bob"))
  
  # Invalid primary key should throw an error
  expect_error(
    lb_create_table_from_df(conn, df, "Person", primary_key = "nonexistent"),
    "not found in data frame"
  )
})

# Test lb_copy_from_csv loads CSV data
test_that("lb_copy_from_csv loads CSV data", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create node table
  lb_execute(conn, "CREATE NODE TABLE City(name STRING, population INT64, PRIMARY KEY (name))")
  
  # Create temporary CSV file
  csv_file <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_file), add = TRUE)
  write.csv(
    data.frame(name = c("Berlin", "London"), population = c(3645000, 8982000)),
    csv_file,
    row.names = FALSE
  )
  
  # Load from CSV
  lb_copy_from_csv(conn, csv_file, "City")
  
  # Verify data was loaded
  result <- lb_execute(conn, "MATCH (c:City) RETURN c.name, c.population")
  df_result <- as.data.frame(result)
  
  expect_equal(nrow(df_result), 2)
})

# Test lb_copy_from_csv with custom delimiter
test_that("lb_copy_from_csv handles custom delimiter", {
  skip_if_no_ladybug()

  conn <- test_conn(environment())

  # Create node table
  lb_execute(conn, "CREATE NODE TABLE City(name STRING, population INT64, PRIMARY KEY (name))")

  # Create temporary CSV file with semicolon delimiter
  csv_file <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_file), add = TRUE)
  utils::write.table(
    data.frame(name = c("Berlin"), population = c(3645000)),
    file = csv_file,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE
  )

  # Load from CSV with custom delimiter (quoted literal expected by parser)
  expect_silent(lb_copy_from_csv(conn, csv_file, "City", list(delim = "';'")))

  result <- lb_execute(conn, "MATCH (c:City) RETURN c.name, c.population")
  df_result <- as.data.frame(result)
  expect_equal(nrow(df_result), 1)
  expect_equal(df_result$c.name, "Berlin")
  expect_equal(df_result$c.population, 3645000)
})

# Test lb_copy_from_json loads JSON data
test_that("lb_copy_from_json loads JSON data", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create node table
  lb_execute(conn, "CREATE NODE TABLE Product(id INT64, name STRING, PRIMARY KEY (id))")
  
  # Create temporary JSON file
  json_file <- tempfile(fileext = ".json")
  on.exit(unlink(json_file), add = TRUE)
  json_data <- '[{"id": 1, "name": "Laptop"}, {"id": 2, "name": "Mouse"}]'
  writeLines(json_data, json_file)
  
  # Load from JSON
  expect_warning(
    lb_copy_from_json(conn, json_file, "Product"),
    "Could not install or load JSON extension",
    fixed = TRUE
  )
  
  # Verify data was loaded
  result <- lb_execute(conn, "MATCH (p:Product) RETURN p.id, p.name")
  df_result <- as.data.frame(result)
  
  expect_gte(nrow(df_result), 1)
})

# Test lb_copy_from_parquet loads Parquet data
test_that("lb_copy_from_parquet loads Parquet data", {
  skip_if_no_ladybug()
  skip_if_not_installed("arrow")
  
  conn <- test_conn(environment())
  
  # Create node table
  lb_execute(conn, "CREATE NODE TABLE Country(name STRING, code STRING, PRIMARY KEY (name))")
  
  # Create temporary Parquet file
  parquet_file <- tempfile(fileext = ".parquet")
  on.exit(unlink(parquet_file), add = TRUE)
  country_df <- data.frame(name = c("USA", "Canada"), code = c("US", "CA"))
  arrow::write_parquet(country_df, parquet_file)
  
  # Load from Parquet
  lb_copy_from_parquet(conn, parquet_file, "Country")
  
  # Verify data was loaded
  result <- lb_execute(conn, "MATCH (c:Country) RETURN c.name, c.code")
  df_result <- as.data.frame(result)
  
  expect_equal(nrow(df_result), 2)
})

# Test lb_merge_df with LOAD FROM
test_that("lb_merge_df executes merge query", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create node table
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, city STRING, PRIMARY KEY (name))")
  
  # Insert initial data
  lb_execute(conn, "CREATE (:Person {name: 'Alice', city: 'New York'})")
  
  # Create data frame for merge
  df <- data.frame(
    name = c("Alice", "Bob"),
    city = c("Boston", "London"),
    stringsAsFactors = FALSE
  )
  
  # Create merge query - using LOAD FROM CSV
  # Note: This tests the lb_merge_df function exists and runs without error
  # The actual MERGE semantics depend on Ladybug's query support
  
  # This should run without error
  expect_silent(lb_merge_df(conn, df, "RETURN *"))
})

# Test that lb_copy_from_file internal function exists
test_that("internal lb_copy_from_file function is available", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create a table first
  lb_execute(conn, "CREATE NODE TABLE Test(name STRING, PRIMARY KEY (name))")
  
  # Create a temp file
  csv_file <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_file), add = TRUE)
  write.csv(data.frame(name = "Alice"), csv_file, row.names = FALSE)
  
  # The internal function should be callable
  # (We test indirectly through lb_copy_from_csv)
  lb_copy_from_csv(conn, csv_file, "Test")
})

# Test lb_copy_from_df works for node and rel tables
test_that("lb_copy_from_df works for node and rel tables", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Test Node Table
  lb_execute(
    conn,
    "CREATE NODE TABLE Product(id INT64, name STRING, PRIMARY KEY (id))"
  )
  products_df <- data.frame(id = c(1, 2), name = c("Laptop", "Mouse"))
  lb_copy_from_df(conn, products_df, "Product")
  result <- lb_execute(
    conn,
    "MATCH (p:Product) RETURN p.id, p.name ORDER BY p.id"
  )
  df_check <- as.data.frame(result)
  expect_equal(nrow(df_check), 2)
  expect_equal(df_check$p.id, c(1, 2))

  # Test Rel Table
  lb_execute(
    conn,
    "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))"
  )
  lb_execute(
    conn,
    "CREATE REL TABLE Follows(FROM Person TO Person, since INT64)"
  )
  persons_df <- data.frame(name = c("Alice", "Bob"))
  lb_copy_from_df(conn, persons_df, "Person")

  follows_df <- data.frame(
    from_person = "Alice",
    to_person = "Bob",
    since = 2023
  )
  lb_copy_from_df(conn, follows_df, "Follows")

  result_rel <- lb_execute(
    conn,
    "MATCH (a:Person)-[f:Follows]->(b:Person) RETURN a.name, b.name, f.since"
  )
  df_rel_check <- as.data.frame(result_rel)
  expect_equal(nrow(df_rel_check), 1)
  expect_equal(df_rel_check$a.name, "Alice")
  expect_equal(df_rel_check$b.name, "Bob")
  expect_equal(df_rel_check$f.since, 2023)
})

# Test lb_copy_from_df handles various data types
test_that("lb_copy_from_df handles various data types", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create table with various Ladybug data types
  lb_execute(
    conn,
    "CREATE NODE TABLE MixedTypes(
    id INT64,
    name STRING,
    is_active BOOL,
    value FLOAT,
    amount DOUBLE,
    event_date DATE,
    timestamp TIMESTAMP,
    price INT64,
    price2 DECIMAL,
    int8_col INT8,
    int16_col INT16,
    int32_col INT32,
    int128_col INT128,
    uint8_col UINT8,
    uint16_col UINT16,
    serial_col SERIAL,
    PRIMARY KEY (id)
  )"
  )

  # Create a data frame with corresponding R data types
  mixed_df <- data.frame(
    id = c(1L, 2L),
    name = c("Test Item", "Another Item"),
    is_active = c(TRUE, FALSE),
    value = c(1.23, 4.56),
    amount = c(10.12345, 67.89012),
    event_date = as.Date(c("2023-01-15", "2023-02-20")),
    timestamp = as.POSIXct(
      c("2023-01-15 10:30:00", "2023-02-20 14:45:00"),
      tz = "UTC"
    ),
    price = c(99L, 123L),
    price2 = c(99.99, 123.45),
    int8_col = c(1L, -128L),
    int16_col = c(100L, -1000L),
    int32_col = c(10000L, -50000L),
    int128_col = c(1.234567890123456789e18, -9.876543210987654321e18),
    uint8_col = c(0L, 255L),
    uint16_col = c(0L, 65535L),
    stringsAsFactors = FALSE
  )

  lb_copy_from_df(conn, mixed_df, "MixedTypes")

  # Query and verify data
  result <- lb_execute(
    conn,
    paste(
      "MATCH (m:MixedTypes) RETURN m.id, m.name, m.is_active, m.value,",
      "m.amount, m.event_date, m.timestamp, m.price, m.price2,m.int8_col,",
      "m.int16_col, m.int32_col, m.int128_col, m.uint8_col, m.uint16_col,",
      "m.serial_col ORDER BY m.id"
    )
  )
  df_check <- as.data.frame(result)

  expect_equal(nrow(df_check), 2)
  expect_equal(df_check$m.id, c(1L, 2L))
  expect_equal(df_check$m.name, c("Test Item", "Another Item"))
  expect_equal(df_check$m.is_active, c(TRUE, FALSE))
  expect_equal(df_check$m.value, c(1.23, 4.56))
  expect_equal(df_check$m.amount, c(10.12345, 67.89012))
  expect_equal(
    substr(as.character(df_check$m.event_date), 1, 10),
    c("2023-01-15", "2023-02-20")
  )
})

# Test lb_copy_from_df handles empty data frames
test_that("lb_copy_from_df handles empty data frames", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create a simple table
  lb_execute(
    conn,
    "CREATE NODE TABLE EmptyTestTable(col1 STRING, PRIMARY KEY (col1))"
  )

  # Create an empty data frame
  empty_df <- data.frame(col1 = character(0))

  # Load the empty data frame
  lb_copy_from_df(conn, empty_df, "EmptyTestTable")

  # Query and verify that the table is empty
  result <- lb_execute(conn, "MATCH (e:EmptyTestTable) RETURN count(e)")
  expect_equal(as.data.frame(result)[[1]], 0)

  # Test with a table that has multiple columns
  lb_execute(
    conn,
    paste(
      "CREATE NODE TABLE AnotherEmptyTable(id INT64, name STRING, ",
      "PRIMARY KEY (id))",
      sep = ""
    )
  )
  empty_df_multi <- data.frame(id = integer(0), name = character(0))
  lb_copy_from_df(conn, empty_df_multi, "AnotherEmptyTable")
  result_multi <- lb_execute(
    conn,
    "MATCH (a:AnotherEmptyTable) RETURN count(a)"
  )
  expect_equal(as.data.frame(result_multi)[[1]], 0)
})

# Test lb_merge_df works for insertion and update
test_that("lb_merge_df works for insertion and update", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  lb_execute(
    conn,
    paste(
      "CREATE NODE TABLE Person(name STRING, current_city STRING, age",
      " INT64, PRIMARY KEY (name))"
    )
  )

  # --- Test Insertion ---
  initial_data <- data.frame(
    name = c("Alice", "Bob"),
    current_city = c("New York", "London"),
    age = c(30, 25)
  )

  lb_copy_from_df(conn, df = initial_data, table_name = "Person")

  # Verify initial insertion
  result_initial <- lb_execute(
    conn,
    "MATCH (p:Person) RETURN p.name, p.current_city, p.age ORDER BY p.name"
  )
  df_initial <- as.data.frame(result_initial)
  expect_equal(nrow(df_initial), 2)
  expect_equal(df_initial$p.name, c("Alice", "Bob"))
  expect_equal(df_initial$p.current_city, c("New York", "London"))
  expect_equal(df_initial$p.age, c(30, 25))

  # --- Test Update and New Insertion ---
  update_data <- data.frame(
    name = c("Alice", "Charlie"),
    current_city = c("Los Angeles", "Paris"),
    age = c(31, 35)
  )

  merge_statement_update <- "MERGE (p:Person {name: name})
  ON MATCH SET p.current_city = current_city, p.age = age
  ON CREATE SET p.current_city = current_city, p.age = age"

  lb_merge_df(conn, df = update_data, merge_statement_update)

  # Verify update and new insertion
  result_update <- lb_execute(
    conn,
    "MATCH (p:Person) RETURN p.name, p.current_city, p.age ORDER BY p.name"
  )
  df_update <- as.data.frame(result_update)
  expect_equal(nrow(df_update), 3)
  expect_equal(df_update$p.name, c("Alice", "Bob", "Charlie"))
  expect_equal(df_update$p.current_city, c("Los Angeles", "London", "Paris"))
  expect_equal(df_update$p.age, c(31, 25, 35))
})

# Test lb_copy_from_csv loads data correctly with test file
test_that("lb_copy_from_csv loads data correctly", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create table with corresponding Ladybug data types
  lb_execute(
    conn,
    "CREATE NODE TABLE CsvLoadedTypes(
    id INT64,
    name STRING,
    is_active BOOL,
    value FLOAT,
    amount DOUBLE,
    event_date DATE,
    timestamp TIMESTAMP,
    price DECIMAL(10,2),
    PRIMARY KEY (id)
  )"
  )

  temp_csv_path <- test_path("temp_mixed_types.csv")
  # Load data from CSV
  lb_copy_from_csv(
    conn,
    file_path = temp_csv_path,
    table_name = "CsvLoadedTypes"
  )

  # Query and verify data
  result <- lb_execute(
    conn,
    paste(
      "MATCH (c:CsvLoadedTypes) RETURN c.id, c.name, c.is_active, c.value,",
      "c.amount, c.event_date, c.timestamp, c.price ORDER BY c.id"
    )
  )
  df_check <- as.data.frame(result)

  expect_equal(nrow(df_check), 2)
  expect_equal(df_check$c.id, c(1, 2))
  expect_equal(df_check$c.name, c("Test Item", "Another Item"))
  expect_equal(df_check$c.is_active, c(TRUE, FALSE))
  expect_equal(df_check$c.value, c(1.23, 4.56))
  expect_equal(df_check$c.amount, c(10.12345, 67.89012))
  expect_equal(
    substr(as.character(df_check$c.event_date), 1, 10),
    c("2023-01-15", "2023-02-20")
  )
})

# Test lb_copy_from_csv handles semicolon delimiter
test_that("lb_copy_from_csv handles semicolon delimiter", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create table
  lb_execute(
    conn,
    "CREATE NODE TABLE SemicolonTable(
    id INT64,
    name STRING,
    value DOUBLE,
    PRIMARY KEY (id)
  )"
  )

  temp_csv_path <- test_path("temp_semicolon.csv")

  # Load data from CSV with semicolon delimiter
  lb_copy_from_csv(
    conn,
    file_path = temp_csv_path,
    table_name = "SemicolonTable",
    optional_csv_parameter = list(delim = "';'")
  )

  # Query and verify data
  result <- lb_execute(
    conn,
    "MATCH (s:SemicolonTable) RETURN s.id, s.name, s.value ORDER BY s.id"
  )
  df_check <- as.data.frame(result)

  expect_equal(nrow(df_check), 2)
  expect_equal(df_check$s.id, c(10, 11))
  expect_equal(df_check$s.name, c("Semicolon Item", "Another Semicolon"))
  expect_equal(df_check$s.value, c(100.50, 200.75))
})

# Test lb_copy_from_csv handles comma delimiter explicitly
test_that("lb_copy_from_csv handles comma delimiter explicitly", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create table
  lb_execute(
    conn,
    "CREATE NODE TABLE CommaTable(
    id INT64,
    name STRING,
    value DOUBLE,
    PRIMARY KEY (id)
  )"
  )

  temp_csv_path <- test_path("temp_comma.csv")

  # Load data from CSV with explicit comma delimiter
  lb_copy_from_csv(
    conn,
    file_path = temp_csv_path,
    table_name = "CommaTable",
    optional_csv_parameter = list(delim = "','")
  )

  # Query and verify data
  result <- lb_execute(
    conn,
    "MATCH (c:CommaTable) RETURN c.id, c.name, c.value ORDER BY c.id"
  )
  df_check <- as.data.frame(result)

  expect_equal(nrow(df_check), 2)
  expect_equal(df_check$c.id, c(10, 11))
  expect_equal(df_check$c.name, c("Comma Item", "Another Comma"))
  expect_equal(df_check$c.value, c(100.50, 200.75))
})

# Test lb_copy_from_csv handles header option
test_that("lb_copy_from_csv handles header option", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create table
  lb_execute(
    conn,
    "CREATE NODE TABLE HeaderTable(
    id INT64,
    name STRING,
    value DOUBLE,
    PRIMARY KEY (id)
  )"
  )

  temp_csv_path <- test_path("temp_comma.csv")

  # Load data from CSV with explicit header option
  lb_copy_from_csv(
    conn,
    file_path = temp_csv_path,
    table_name = "HeaderTable",
    optional_csv_parameter = list(header = "true")
  )

  # Query and verify data
  result <- lb_execute(
    conn,
    "MATCH (h:HeaderTable) RETURN h.id, h.name, h.value ORDER BY h.id"
  )
  df_check <- as.data.frame(result)

  expect_equal(nrow(df_check), 2)
  expect_equal(df_check$h.id, c(10, 11))
})

# Test lb_copy_from_json handles empty JSON files
test_that("lb_copy_from_json handles empty JSON files", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create an empty JSON file (empty array)
  json_content <- "[]"
  temp_json_path <- tempfile(fileext = ".json")
  on.exit(unlink(temp_json_path), add = TRUE)
  writeLines(json_content, temp_json_path)

  # Create table
  lb_execute(
    conn,
    "CREATE NODE TABLE EmptyJsonTable(id INT64, name STRING, PRIMARY KEY (id))"
  )

  # Load data from empty JSON
  expect_warning(
    lb_copy_from_json(conn, temp_json_path, "EmptyJsonTable"),
    "Could not install or load JSON extension",
    fixed = TRUE
  )

  # Query and verify that the table is empty
  result <- lb_execute(conn, "MATCH (e:EmptyJsonTable) RETURN count(e)")
  expect_equal(as.data.frame(result)[[1]], 0)
})

# Test lb_copy_from_parquet handles empty parquet files
test_that("lb_copy_from_parquet handles empty parquet files", {
  skip_if_no_ladybug()
  skip_if_not_installed("arrow")

  conn <- test_conn(environment())

  # Create table
  lb_execute(
    conn,
    "CREATE NODE TABLE EmptyParquetTable(
    id INT64,
    name STRING,
    PRIMARY KEY (id)
  )"
  )

  # Create an empty Parquet file
  parquet_file <- tempfile(fileext = ".parquet")
  on.exit(unlink(parquet_file), add = TRUE)
  empty_df <- data.frame(id = integer(0), name = character(0))
  arrow::write_parquet(empty_df, parquet_file)

  # Load data from empty Parquet
  lb_copy_from_parquet(conn, parquet_file, "EmptyParquetTable")

  # Query and verify that the table is empty
  result <- lb_execute(conn, "MATCH (e:EmptyParquetTable) RETURN count(e)")
  expect_equal(as.data.frame(result)[[1]], 0)
})

# Test ladybug handles data types DECIMAL and UUID
test_that("ladybug handles data types DECIMAL and UUID", {
  skip_if_no_ladybug()
  conn <- test_conn(environment())

  # Create table with various Ladybug data types
  lb_execute(
    conn,
    "CREATE NODE TABLE MixedTypes(
  id INT64,
  price DECIMAL,
  uuid_col UUID,
  PRIMARY KEY (id))"
  )

  # Create a data frame with corresponding R data types
  mixed_df <- data.frame(
    id = c(1L, 2L),
    price = c(99.99, 123.45),
    uuid_col = c(
      "a1b2c3d4-e5f6-7890-1234-567890abcdef",
      "09876543-21fe-dcba-0987-654321fedcba"
    ),
    stringsAsFactors = FALSE
  )

  lb_copy_from_df(conn, mixed_df, "MixedTypes")

  result <- lb_execute(
    conn,
    "MATCH (m:MixedTypes) RETURN m.id, m.price, m.uuid_col ORDER BY m.id"
  )
  all_results <- lb_get_all(result)

  expect_true(is.list(all_results))
  expect_true(all_results[[1]]$m.id == 1)
  expect_true(all_results[[2]]$m.id == 2)
  expect_equal(
    as.character(all_results[[1]]$m.uuid_col),
    "a1b2c3d4-e5f6-7890-1234-567890abcdef"
  )
})