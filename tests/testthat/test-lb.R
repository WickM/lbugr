# Tests for lbugr Core Connection and Query Functions

# Skip all tests if ladybug is not available
skip_if_no_ladybug <- function() {
  if (!reticulate::py_module_available("real_ladybug")) {
    skip("real_ladybug Python package not available")
  }
}

# Test that lb_connection returns a connection object
test_that("lb_connection creates an in-memory database connection", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  expect_s3_class(conn, "python.builtin.object")
})

# Test that lb_connection can create a disk-based database
test_that("lb_connection creates a disk-based database", {
  skip_if_no_ladybug()
  
  temp_db_dir <- file.path(tempdir(), "test_lbugr_db")
  dir.create(temp_db_dir, recursive = TRUE, showWarnings = FALSE)
  db_path <- file.path(temp_db_dir, "test.db")
  
  conn <- lb_connection(db_path)
  on.exit({
    cleanup_db()
    unlink(temp_db_dir, recursive = TRUE)
  }, add = TRUE)
  expect_s3_class(conn, "python.builtin.object")
})

# Test that lb_connection creates database if not exists
test_that("lb_connection creates database if not exists", {
  skip_if_no_ladybug()
  
  temp_db_dir <- file.path(tempdir(), "test_lbugr_newdb")
  dir.create(temp_db_dir, recursive = TRUE, showWarnings = FALSE)
  db_path <- file.path(temp_db_dir, "new.db")
  
  # Should create new database
  conn <- lb_connection(db_path)
  on.exit({
    cleanup_db()
    unlink(temp_db_dir, recursive = TRUE)
  }, add = TRUE)
  expect_s3_class(conn, "python.builtin.object")
  
  # Verify database was created
  expect_true(file.exists(db_path))
})

# Test that lb_execute executes a simple query
test_that("lb_execute executes a simple query", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create a node table
  result <- lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64, PRIMARY KEY (name))")
  expect_s3_class(result, "data.frame")
  
  # Insert a node
  result <- lb_execute(conn, "CREATE (:User {name: 'Alice', age: 30})")
  expect_s3_class(result, "data.frame")
})

# Test that lb_execute returns query results
test_that("lb_execute returns query results with data", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create a node table
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  
  # Insert nodes
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  
  # Query the data
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age ORDER BY p.name")
  
  expect_s3_class(result, "data.frame")
})

# Test lb_get_column_names
test_that("lb_get_column_names returns column names", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age")
  col_names <- lb_get_column_names(result)
  
  expect_type(col_names, "character")
  expect_true("p.name" %in% col_names || "name" %in% col_names)
})

# Test lb_get_column_data_types
test_that("lb_get_column_data_types returns data types", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age")
  col_types <- lb_get_column_data_types(result)
  
  expect_type(col_types, "character")
  expect_true(length(col_types) >= 1)
})

# Test lb_get_schema
test_that("lb_get_schema returns schema information", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age")
  schema <- lb_get_schema(result)
  
  expect_type(schema, "character")
})

# Test lb_get_all retrieves all results
test_that("lb_get_all retrieves all results", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name ORDER BY p.name")
  all_results <- lb_get_all(result)
  
  expect_type(all_results, "list")
  expect_gte(length(all_results), 1)
})

# Test lb_get_n retrieves first n rows
test_that("lb_get_n retrieves first n rows", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  lb_execute(conn, "CREATE (:Person {name: 'Charlie'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name ORDER BY p.name")
  first_two <- lb_get_n(result, 2)
  
  expect_type(first_two, "list")
  expect_lte(length(first_two), 2)
})

# Test lb_get_next iterates through results
test_that("lb_get_next iterates through results", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name ORDER BY p.name")
  
  row1 <- lb_get_next(result)
  expect_type(row1, "list")
  
  row2 <- lb_get_next(result)
  expect_type(row2, "list")
  
  row3 <- lb_get_next(result)
  expect_null(row3)
})

# Test lb_get_n with n=0 returns empty list
test_that("lb_get_n with n=0 returns empty list", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name")
  zero_rows <- lb_get_n(result, 0)
  
  expect_type(zero_rows, "list")
  expect_equal(length(zero_rows), 0)
})

# Test lb_get_n with n greater than available rows
test_that("lb_get_n handles n greater than available rows", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name")
  # Request more rows than exist
  many_rows <- lb_get_n(result, 100)
  
  expect_type(many_rows, "list")
  expect_lte(length(many_rows), 1)
})

# Test as.data.frame method on query result
test_that("as.data.frame converts query result to data.frame", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age ORDER BY p.name")
  # lb_execute now returns a data.frame directly, so as.data.frame works standard way
  df <- as.data.frame(result)
  
  expect_s3_class(df, "data.frame")
  expect_gte(nrow(df), 1)
})

# Test as_tibble method on query result
test_that("as_tibble converts query result to tibble", {
  skip_if_no_ladybug()
  skip_if_not_installed("tibble")
  library(tibble)  # Load tibble for as_tibble function
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name")
  # lb_execute now returns a data.frame directly
  tbl <- as_tibble(result)
  
  expect_s3_class(tbl, "tbl_df")
})

# Test as.data.frame on empty result
test_that("as.data.frame handles empty results", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name")
  # lb_execute returns data.frame directly now
  df <- as.data.frame(result)
  
  expect_s3_class(df, "data.frame")
})

# Test query with aggregation
test_that("lb_execute handles aggregation queries", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'A', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'B', age: 30})")
  lb_execute(conn, "CREATE (:Person {name: 'C', age: 35})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN AVG(p.age) AS avg_age")
  # lb_execute returns data.frame directly now
  df <- as.data.frame(result)
  
  expect_s3_class(df, "data.frame")
  expect_gte(ncol(df), 1)
})

# Test query with WHERE clause
test_that("lb_execute handles WHERE clauses", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  lb_execute(conn, "CREATE (:Person {name: 'Charlie', age: 35})")
  
  result <- lb_execute(conn, "MATCH (p:Person) WHERE p.age > 28 RETURN p.name, p.age")
  # lb_execute returns data.frame directly now
  df <- as.data.frame(result)
  
  expect_s3_class(df, "data.frame")
})

# Test query with ORDER BY
test_that("lb_execute handles ORDER BY", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Charlie', age: 35})")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name ORDER BY p.name")
  df <- as.data.frame(result)
  
  expect_equal(df$p.name[1], "Alice")
})

# Test query with LIMIT
test_that("lb_execute handles LIMIT", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'A'})")
  lb_execute(conn, "CREATE (:Person {name: 'B'})")
  lb_execute(conn, "CREATE (:Person {name: 'C'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name LIMIT 2")
  df <- as.data.frame(result)
  
  expect_lte(nrow(df), 2)
})

# Test query with DISTINCT
test_that("lb_execute handles DISTINCT", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, city STRING, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'A', city: 'NYC'})")
  lb_execute(conn, "CREATE (:Person {name: 'B', city: 'NYC'})")
  lb_execute(conn, "CREATE (:Person {name: 'C', city: 'LA'})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN DISTINCT p.city")
  df <- as.data.frame(result)
  
  expect_equal(nrow(df), 2)
})

# Test lb_get_column_data_types with different types
test_that("lb_get_column_data_types returns correct types", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE TypesTest(id INT64, name STRING, value DOUBLE, flag BOOLEAN, PRIMARY KEY (id))")
  lb_execute(conn, "CREATE (:TypesTest {id: 1, name: 'test', value: 1.5, flag: true})")
  
  result <- lb_execute(conn, "MATCH (t:TypesTest) RETURN t.id, t.name, t.value, t.flag")
  col_types <- lb_get_column_data_types(result)
  
  expect_type(col_types, "character")
  expect_gte(length(col_types), 3)
})

# Test lb_get_all on result with multiple columns
test_that("lb_get_all handles multiple columns", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age")
  all_results <- lb_get_all(result)
  
  expect_gte(length(all_results), 1)
  expect_type(all_results[[1]], "list")
})

# Test lb_get_next returns correct data structure
test_that("lb_get_next returns correct data structure", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.name, p.age")
  row <- lb_get_next(result)
  
  expect_type(row, "list")
  expect_true("p.name" %in% names(row) || "name" %in% names(row))
})