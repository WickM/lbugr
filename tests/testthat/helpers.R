# Test Helper Functions and Fixtures for lbugr
#
# This file provides shared test utilities, fixtures, and helper functions
# to support the test suite.

#' Skip test if ladybug Python package is not available
#'
#' @keywords internal
skip_if_no_ladybug <- function() {
  ladybug_avail <- reticulate::py_module_available("ladybug")

  if (!ladybug_avail) {
    skip("ladybug Python package not available")
  }
}

#' Clean up test database resources
#'
#' Shuts down the Ladybug database and removes temporary database files.
#' This is critical to prevent memory accumulation and VirtualAlloc errors
#' when running many tests in sequence.
#'
#' @param conn Connection object (optional)
#' @param db_dir Database directory to remove (optional)
cleanup_db <- function(conn = NULL, db_dir = NULL) {
  # Use connection-attached db_dir when not passed explicitly
  if (is.null(db_dir) && !is.null(conn)) {
    db_dir <- attr(conn, "lbugr_test_db_dir", exact = TRUE)
  }

  # Try shutdown through passed connection's Python main context
  if (!is.null(conn)) {
    tryCatch(
      {
        main <- reticulate::import_main()
        main$conn <- conn
        reticulate::py_run_string(
          "try:\n    conn.database.shutdown()\nexcept Exception:\n    pass",
          convert = FALSE
        )
      },
      error = function(e) {
        # Ignore cleanup errors
      }
    )
  }

  # Try shutdown through global main$db if present
  tryCatch(
    {
      main <- reticulate::import_main()
      if (!is.null(main$db)) {
        main$db$shutdown()
      }
    },
    error = function(e) {
      # Ignore cleanup errors
    }
  )

  # Encourage prompt resource release between tests
  tryCatch(gc(), error = function(e) NULL)

  # Remove temp database directory if provided
  if (!is.null(db_dir) && nzchar(db_dir) && dir.exists(db_dir)) {
    tryCatch(unlink(db_dir, recursive = TRUE, force = TRUE), error = function(e) NULL)
  }

  invisible(NULL)
}

#' Create a unique test database path in tempdir
#'
#' @return A list with db_dir and db_path
create_test_db_path <- function() {
  db_dir <- tempfile(pattern = "lbugr_test_db_")
  dir.create(db_dir, recursive = TRUE, showWarnings = FALSE)
  list(db_dir = db_dir, db_path = file.path(db_dir, "test.db"))
}

#' Create a temporary test database connection
#'
#' This fixture creates an in-memory Ladybug connection for each test.
#' In-memory databases are faster than on-disk databases and don't require
#' file system cleanup.
#'
#' @param test Test environment passed by testthat (optional)
#' @return A Ladybug connection object
test_conn <- function(test = NULL) {
  # Use in-memory database for faster test execution
  conn <- lb_connection(":memory:")

  # Register cleanup only when a test env is provided
  if (!is.null(test)) {
    test$old_conn <- conn
    withr::defer(cleanup_db(conn = conn), envir = test)
  }

  conn
}

#' Clean up test resources
#'
#' @param conn A connection object to clean up (optional)
cleanup_test_resources <- function(conn = NULL) {
  cleanup_db(conn)
}

#' Create test data frames for common test scenarios
#'
#' @param type Type of test data: "simple", "with_nulls", "with_dates", "large"
#' @return A data frame with test data
create_test_df <- function(type = "simple") {
  switch(
    type,
    "simple" = data.frame(
      id = 1:3,
      name = c("Alice", "Bob", "Charlie"),
      age = c(25L, 30L, 35L),
      stringsAsFactors = FALSE
    ),
    "with_nulls" = data.frame(
      id = 1:3,
      name = c("Alice", NA, "Charlie"),
      age = c(25L, NA, 35L),
      stringsAsFactors = FALSE
    ),
    "with_dates" = data.frame(
      id = 1:2,
      name = c("Alice", "Bob"),
      birth_date = as.Date(c("1990-01-01", "1985-05-15")),
      stringsAsFactors = FALSE
    ),
    "with_logical" = data.frame(
      id = 1:2,
      name = c("Alice", "Bob"),
      is_active = c(TRUE, FALSE),
      stringsAsFactors = FALSE
    ),
    "large" = data.frame(
      id = 1:100,
      name = paste0("Person", 1:100),
      age = rep(25:35, length.out = 100),
      stringsAsFactors = FALSE
    ),
    stop("Unknown test data type: ", type)
  )
}

#' Create a temporary file with test data
#'
#' @param extension File extension (e.g., ".csv", ".json", ".parquet")
#' @param data_type Type of data to create
#' @return Path to the temporary file
create_temp_file <- function(extension = ".csv", data_type = "simple") {
  temp_file <- tempfile(fileext = extension)
  on.exit(unlink(temp_file), add = TRUE)
  
  df <- create_test_df(data_type)
  
  if (extension == ".csv") {
    write.csv(df, temp_file, row.names = FALSE)
  } else if (extension == ".json") {
    json_data <- jsonlite::toJSON(df, auto_unbox = TRUE)
    writeLines(json_data, temp_file)
  } else if (extension == ".parquet") {
    if (requireNamespace("arrow", quietly = TRUE)) {
      arrow::write_parquet(df, temp_file)
    } else {
      skip("arrow package not available")
    }
  }
  
  temp_file
}

#' Setup test database with schema
#'
#' Creates a standard test database with Person and Knows tables.
#'
#' @param conn A Ladybug connection
#' @param include_relationships Whether to create relationship tables
setup_test_db <- function(conn, include_relationships = FALSE) {
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 25})")
  lb_execute(conn, "CREATE (:Person {name: 'Bob', age: 30})")
  lb_execute(conn, "CREATE (:Person {name: 'Charlie', age: 35})")
  
  if (include_relationships) {
    lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
    lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Alice' AND b.name='Bob' CREATE (a)-[:Knows]->(b)")
    lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name='Bob' AND b.name='Charlie' CREATE (a)-[:Knows]->(b)")
  }
  
  invisible(conn)
}

#' Skip test if required package is not available
#'
#' @param pkg Package name
skip_if_pkg_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    skip(paste(pkg, "package not available"))
  }
}

#' Test helper for verifying query results
#'
#' @param result A Ladybug query result
#' @param expected_rows Expected number of rows
#' @param expected_cols Expected number of columns (optional)
verify_result <- function(result, expected_rows = NULL, expected_cols = NULL) {
  expect_s3_class(result, "python.builtin.object")
  
  col_names <- lb_get_column_names(result)
  expect_type(col_names, "character")
  expect_true(length(col_names) > 0)
  
  if (!is.null(expected_cols)) {
    expect_equal(length(col_names), expected_cols)
  }
  
  if (!is.null(expected_rows)) {
    df <- as.data.frame(result)
    expect_equal(nrow(df), expected_rows)
  }
}

#' Test helper for verifying data frame contents
#'
#' @param df A data frame
#' @param col_name Column name to check
#' @param expected_values Expected values in the column
verify_dataframe <- function(df, col_name, expected_values) {
  expect_s3_class(df, "data.frame")
  expect_true(col_name %in% names(df))
  expect_equal(df[[col_name]], expected_values)
}
