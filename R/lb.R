# Core Connection and Query Functions for lbugr

# Cache environment for lb_get_next iteration position
.lbugr_iter_cache <- new.env(parent = emptyenv())

#' Create a Connection to a Ladybug Database
#'
#' Establishes a connection to a Ladybug database. If the database does not exist
#' at the specified path, it will be created. This function combines the
#' database initialization and connection steps into a single call.
#'
#' @param path A string specifying the file path for the database. For an
#'   in-memory database, use `":memory:"`.
#' @return A Python object representing the connection to the Ladybug database.
#' @export
#' @examples
#' \donttest{
#' # Create an in-memory database and connection
#' conn <- lb_connection(":memory:")
#'
#' # Create or connect to an on-disk database
#' temp_db_dir <- file.path(tempdir(), "ladybug_disk_example_db")
#' db_path <- file.path(temp_db_dir, "ladybug_db")
#' dir.create(temp_db_dir, recursive = TRUE, showWarnings = FALSE)
#'
#' # Establish connection
#' conn_disk <- lb_connection(db_path)
#'
#' # Ensure the database is shut down and removed on exit
#' on.exit({
#'   # Access the 'db' object from the reticulate main module
#'   main <- reticulate::import_main()
#'   if (!is.null(main$db)) {
#'     main$db$shutdown()
#'   }
#'   unlink(temp_db_dir, recursive = TRUE)
#' })
#' }
lb_connection <- function(path) {
  main <- reticulate::import_main()
  main$path <- path
  reticulate::py_run_string(
    "import real_ladybug; db = real_ladybug.Database(path); conn = real_ladybug.Connection(db)",
    convert = FALSE
  )
  reticulate::py$conn
}

#' Execute a Cypher Query
#'
#' Submits a Cypher query to the Ladybug database for execution. This function
#' is used for all database operations, including schema definition (DDL),
#' data manipulation (DML), and querying (MATCH).
#'
#' @param conn A Ladybug connection object, as returned by `lb_connection()`.
#' @param query A string containing the Cypher query to be executed.
#' @return A Python object representing the query result.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#'
#' # Create a node table
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#'
#' # Insert data
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#'
#' # Query data
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' }
lb_execute <- function(conn, query) {
  main <- reticulate::import_main()
  main$conn <- conn
  main$query <- query
  reticulate::py_run_string("result = conn.execute(query)", convert = FALSE)
  result <- reticulate::py$result
  
  # Pre-convert to data.frame for convenience and proper S3 dispatch
  col_names <- result$get_column_names()
  all_rows <- list()
  while (result$has_next()) {
    all_rows <- c(all_rows, list(result$get_next()))
  }
  
  # Convert list of lists to named lists, converting Python objects to R values
  df_list <- lapply(all_rows, function(row) {
    converted_row <- lapply(row, convert_python_to_r)
    stats::setNames(converted_row, col_names)
  })
  
  # Convert to data.frame
  if (length(df_list) == 0) {
    if (length(col_names) == 0) {
      return(data.frame(stringsAsFactors = FALSE))
    } else {
      return(as.data.frame(
        lapply(col_names, function(x) character(0)),
        stringsAsFactors = FALSE,
        check.names = FALSE
      ))
    }
  } else {
    return(do.call(
      rbind,
      lapply(df_list, function(x) {
        as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
      })
    ))
  }
}

#' Convert a Ladybug Query Result to a Data Frame
#'
#' Provides an S3 method to seamlessly convert a Ladybug query result object into a
#' standard R `data.frame`.
#'
#' @param x A Ladybug query result object.
#' @param ... Additional arguments passed to `as.data.frame`.
#' @return An R `data.frame` containing the query results.
#' @method as.data.frame real_ladybug.query_result.QueryResult
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#'
#' # Convert the result to a data.frame
#' df <- as.data.frame(result)
#' print(df)
#' }
as.data.frame.real_ladybug.query_result.QueryResult <- function(x, ...) {
  col_names <- x$get_column_names()
  all_rows_values <- list()
  while (x$has_next()) {
    all_rows_values <- c(all_rows_values, list(x$get_next()))
  }

  # Convert list of lists to named lists, converting Python objects to R values
  df_list <- lapply(all_rows_values, function(row) {
    converted_row <- lapply(row, convert_python_to_r)
    stats::setNames(converted_row, col_names)
  })

  # Handle empty results
  if (length(df_list) == 0) {
    if (length(col_names) == 0) {
      # No columns, return empty data frame
      data.frame(stringsAsFactors = FALSE)
    } else {
      # Create empty data frame with column names
      as.data.frame(
        lapply(col_names, function(x) character(0)),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
  } else {
    # Convert to data.frame by rbinding named lists
    do.call(
      rbind,
      lapply(df_list, function(x) {
        as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
      })
    )
  }
}

#' Convert a Ladybug Query Result to a Tibble
#'
#' Provides an S3 method to convert a Ladybug query result object into a
#' `tibble`. This requires the `tibble` package to be installed.
#'
#' @param x A Ladybug query result object.
#' @param ... Additional arguments passed to `as_tibble`.
#' @return A `tibble` containing the query results.
#' @importFrom tibble as_tibble
#' @method as_tibble real_ladybug.query_result.QueryResult
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("tibble", quietly = TRUE)) {
#'   conn <- lb_connection(":memory:")
#'   lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#'   PRIMARY KEY (name))")
#'   lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#'   result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#'
#'   # Convert the result to a tibble
#'   tbl <- tibble::as_tibble(result)
#'   print(tbl)
#' }
#' }
as_tibble.real_ladybug.query_result.QueryResult <- function(x, ...) {
  if (!requireNamespace("tibble", quietly = TRUE)) {
    stop(
      "The 'tibble' package is required to use as_tibble(). Please install it.",
      call. = FALSE
    )
  }
  col_names <- x$get_column_names()
  
  all_rows_values <- list()
  while (x$has_next()) {
    all_rows_values <- c(all_rows_values, list(x$get_next()))
  }
  
  # Convert list of lists to named lists, converting Python objects to R values
  df_list <- lapply(all_rows_values, function(row) {
    converted_row <- lapply(row, convert_python_to_r)
    stats::setNames(converted_row, col_names)
  })

  # Handle empty results
  if (length(df_list) == 0) {
    tibble::as_tibble(setNames(list(), col_names))
  } else {
    # Convert to tibble by rbinding named lists
    tibble::as_tibble(do.call(
      rbind,
      lapply(df_list, function(x) {
        as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
      })
    ))
  }
}

#' Retrieve All Rows from a Query Result
#'
#' Fetches all rows from a Ladybug query result and returns them as a list of
#' lists.
#'
#' @param result A Ladybug query result object.
#' @return A list where each element is a list representing a row of results.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' all_results <- lb_get_all(result)
#' }
lb_get_all <- function(result) {
  # Check if result is a data.frame (returned by lb_execute) or Python object
  if (is.data.frame(result)) {
    # Convert each row to a named list
    lapply(seq_len(nrow(result)), function(i) {
      as.list(result[i, , drop = FALSE])
    })
  } else {
    # Original code for raw Python object
    col_names <- result$get_column_names()
    all_rows_values <- list()
    while (result$has_next()) {
      all_rows_values <- c(all_rows_values, list(result$get_next()))
    }
    lapply(all_rows_values, function(row) {
      converted_row <- lapply(row, convert_python_to_r)
      stats::setNames(converted_row, col_names)
    })
  }
}

#' Retrieve the First N Rows from a Query Result
#'
#' Fetches the first `n` rows from a Ladybug query result.
#'
#' @param result A Ladybug query result object.
#' @param n The number of rows to retrieve.
#' @return A list of the first `n` rows.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' lb_execute(conn, "CREATE (:User {name: 'Bob', age: 30})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' first_row <- lb_get_n(result, 1)
#' }
lb_get_n <- function(result, n) {
  # Check if result is a data.frame (returned by lb_execute) or Python object
  if (is.data.frame(result)) {
    # Take first n rows
    head_rows <- head(result, n)
    lapply(seq_len(nrow(head_rows)), function(i) {
      as.list(head_rows[i, , drop = FALSE])
    })
  } else {
    col_names <- result$get_column_names()
    n_rows_values <- result$get_n(as.integer(n))
    lapply(n_rows_values, function(row) {
      converted_row <- lapply(row, convert_python_to_r)
      stats::setNames(converted_row, col_names)
    })
  }
}

#' Retrieve the Next Row from a Query Result
#'
#' Fetches the next available row from a Ladybug query result. This function can be
#' called repeatedly to iterate through results one by one.
#'
#' @param result A Ladybug query result object.
#' @return A list representing the next row, or `NULL` if no more rows are
#' available.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' lb_execute(conn, "CREATE (:User {name: 'Bob', age: 30})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' row1 <- lb_get_next(result)
#' row2 <- lb_get_next(result)
#' }
lb_get_next <- function(result) {
  # Check if result is a data.frame (returned by lb_execute) or Python object
  if (is.data.frame(result)) {
    # Create a hash of the data.frame to use as cache key
    cache_key <- digest::sha1(paste(deparse(result), collapse = ""))
    
    # Get iteration position from cache
    iter_pos <- .lbugr_iter_cache[[cache_key]]
    if (is.null(iter_pos)) {
      iter_pos <- 1
    }
    
    if (iter_pos > nrow(result)) {
      # Clean up cache entry when exhausted
      .lbugr_iter_cache[[cache_key]] <- NULL
      return(NULL)
    }
    
    # Get the row at current position
    row <- as.list(result[iter_pos, ])
    
    # Increment the position for next call
    .lbugr_iter_cache[[cache_key]] <- iter_pos + 1
    
    return(row)
  }
  
  # Original code for raw Python object
  if (!result$has_next()) {
    return(NULL)
  }
  col_names <- result$get_column_names()
  row_values <- result$get_next()
  # Convert Python values to R
  converted_row <- lapply(row_values, convert_python_to_r)
  stats::setNames(converted_row, col_names)
}

#' Get Column Data Types from a Query Result
#'
#' Retrieves the data types of the columns in a Ladybug query result.
#'
#' @param result A Ladybug query result object.
#' @return A character vector of column data types.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' lb_get_column_data_types(result)
#' }
lb_get_column_data_types <- function(result) {
  # Handle data.frame from lb_execute or raw Python object
  if (is.data.frame(result)) {
    return(sapply(result, function(x) typeof(x)))
  }
  result$get_column_data_types()
}

#' Get Column Names from a Query Result
#'
#' Retrieves the names of the columns in a Ladybug query result.
#'
#' @param result A Ladybug query result object.
#' @return A character vector of column names.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' lb_get_column_names(result)
#' }
lb_get_column_names <- function(result) {
  # Handle data.frame from lb_execute or raw Python object
  if (is.data.frame(result)) {
    return(names(result))
  }
  result$get_column_names()
}

#' Get Schema from a Query Result
#'
#' Retrieves the schema (column names and data types) of a Ladybug query result.
#'
#' @param result A Ladybug query result object.
#' @return A named list where names are column names and values are data types.
#' @export
#' @examples
#' \donttest{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' lb_get_schema(result)
#' }
lb_get_schema <- function(result) {
  # Handle data.frame from lb_execute or raw Python object
  if (is.data.frame(result)) {
    return(setNames(sapply(result, function(x) typeof(x)), names(result)))
  }
  result$get_schema()
}

#' Convert Python Objects to R Values
#'
#' Internal helper function to convert Python objects (like Decimal, UUID, nodes) to R values
#'
#' @param x A value that might be a Python object
#' @return An R-compatible value
#' @keywords internal
convert_python_to_r <- function(x) {
  # Handle NULL values from Python - convert to NA
  if (is.null(x)) {
    return(NA)
  }
  if (inherits(x, "python.builtin.object")) {
    # Handle Python Decimal by converting via string to avoid precision loss
    if (inherits(x, "decimal.Decimal")) {
      return(as.numeric(as.character(reticulate::py_str(x))))
    }
    # Handle UUID as string
    if (inherits(x, "uuid.UUID")) {
      return(reticulate::py_str(x))
    }

    # Prefer native conversion for complex Ladybug values (Node/Rel/InternalID)
    # so graph conversion can access `_id`, `_label`, `_src`, `_dst` fields.
    converted <- reticulate::py_to_r(x)
    if (is.list(converted)) {
      return(lapply(converted, convert_python_to_r))
    }

    # Handle other Python objects by converting to string
    return(reticulate::py_str(x))
  }
  # Handle nested lists (e.g., from node/relationship objects that are already converted)
  if (is.list(x)) {
    # Recursively convert each element in the list
    return(lapply(x, convert_python_to_r))
  }
  x
}