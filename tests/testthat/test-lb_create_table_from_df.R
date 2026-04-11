# Tests for lb_create_table_from_df Function

# Skip all tests if ladybug is not available
skip_if_no_ladybug <- function() {
  if (!reticulate::py_module_available("real_ladybug")) {
    skip("real_ladybug Python package not available")
  }
}

# Test lb_create_table_from_df creates table with integer column
test_that("lb_create_table_from_df creates table with INTEGER column", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L, 3L),
    name = c("Alice", "Bob", "Charlie"),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "TestInt", primary_key = "id")
  
  # Verify table was created
  result <- lb_execute(conn, "MATCH (t:TestInt) RETURN t.id, t.name")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
  expect_equal(nrow(df_result), 0)
})

# Test lb_create_table_from_df creates table with numeric column
test_that("lb_create_table_from_df creates table with DOUBLE column", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    height = c(1.75, 1.80),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "TestNumeric", primary_key = "id")
  
  result <- lb_execute(conn, "MATCH (t:TestNumeric) RETURN t.id, t.height")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
})

# Test lb_create_table_from_df creates table with character column
test_that("lb_create_table_from_df creates table with STRING column", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    name = c("Alice", "Bob"),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "TestString", primary_key = "id")
  
  result <- lb_execute(conn, "MATCH (t:TestString) RETURN t.id, t.name")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
})

# Test lb_create_table_from_df creates table with logical column
test_that("lb_create_table_from_df creates table with BOOLEAN column", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    is_active = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "TestBool", primary_key = "id")
  
  result <- lb_execute(conn, "MATCH (t:TestBool) RETURN t.id, t.is_active")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
})

# Test lb_create_table_from_df creates table with Date column
test_that("lb_create_table_from_df creates table with DATE column", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    birth_date = as.Date(c("1990-01-01", "1985-05-15")),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "TestDate", primary_key = "id")
  
  result <- lb_execute(conn, "MATCH (t:TestDate) RETURN t.id, t.birth_date")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
})

# Test lb_create_table_from_df handles multiple columns
test_that("lb_create_table_from_df handles multiple columns", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    name = c("Alice", "Bob"),
    age = c(25L, 30L),
    height = c(1.75, 1.80),
    is_student = c(TRUE, FALSE),
    birth_date = as.Date(c("1995-01-01", "1990-05-15")),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "Person", primary_key = "id")
  
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.id, p.name, p.age, p.height, p.is_student, p.birth_date")
  df_result <- as.data.frame(result)
  
  expect_s3_class(df_result, "data.frame")
  expect_equal(nrow(df_result), 0)
})

# Test lb_create_table_from_df validates primary key column
test_that("lb_create_table_from_df validates primary key exists", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    name = c("Alice", "Bob"),
    stringsAsFactors = FALSE
  )
  
  # Should fail because 'pk' doesn't exist
  expect_error(
    lb_create_table_from_df(conn, df, "Test", primary_key = "pk"),
    "not found in data frame"
  )
})

# Test lb_create_table_from_df warns about factor columns
test_that("lb_create_table_from_df warns about factor columns", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    category = factor(c("A", "B"))
  )
  
  # Should produce a warning about coercion
  expect_warning(
    lb_create_table_from_df(conn, df, "TestFactor", primary_key = "id"),
    "factor"
  )
})

# Test lb_create_table_from_df followed by lb_copy_from_df
test_that("lb_create_table_from_df followed by lb_copy_from_df works", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  # Create source data frame
  source_df <- data.frame(
    id = c(1L, 2L, 3L),
    name = c("Alice", "Bob", "Charlie"),
    age = c(25L, 30L, 35L),
    stringsAsFactors = FALSE
  )
  
  # Create table from data frame
  lb_create_table_from_df(conn, source_df, "Person", primary_key = "id")
  
  # Load additional data
  new_df <- data.frame(
    id = c(4L, 5L),
    name = c("David", "Eve"),
    age = c(40L, 45L),
    stringsAsFactors = FALSE
  )
  lb_copy_from_df(conn, new_df, "Person")
  
  # Verify all data
  result <- lb_execute(conn, "MATCH (p:Person) RETURN p.id, p.name, p.age ORDER BY p.id")
  df_result <- as.data.frame(result)
  
  expect_equal(nrow(df_result), 2)
})

# Test lb_create_table_from_df with empty data frame
test_that("lb_create_table_from_df handles empty data frame", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = integer(0),
    name = character(0),
    stringsAsFactors = FALSE
  )
  
  # Should create an empty table
  expect_silent(lb_create_table_from_df(conn, df, "EmptyTable", primary_key = "id"))
})

# Test lb_create_table_from_df with single row
test_that("lb_create_table_from_df handles single row", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = 1L,
    name = "Alice",
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "SingleRow", primary_key = "id")
  
  result <- lb_execute(conn, "MATCH (s:SingleRow) RETURN s.id, s.name")
  df_result <- as.data.frame(result)
  
  expect_equal(nrow(df_result), 0)
})

# Test lb_create_table_from_df table can be queried for schema
test_that("created table has correct schema", {
  skip_if_no_ladybug()
  
  conn <- test_conn(environment())
  
  df <- data.frame(
    id = c(1L, 2L),
    name = c("Alice", "Bob"),
    age = c(25L, 30L),
    height = c(1.75, 1.80),
    is_active = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  
  lb_create_table_from_df(conn, df, "SchemaTest", primary_key = "id")
  
  # Get the schema through query
  result <- lb_execute(conn, "MATCH (s:SchemaTest) RETURN s.id, s.name, s.age, s.height, s.is_active")
  schema_info <- lb_get_schema(result)
  
  expect_type(schema_info, "character")
  expect_gte(length(schema_info), 1)
})