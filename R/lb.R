# Core Connection and Query Functions for lbugr

# Cache environment for lb_get_next iteration position
.lbugr_iter_cache <- new.env(parent = emptyenv())

query_result_to_df <- function(py_result) {
  col_names <- reticulate::py_to_r(py_result$get_column_names())
  all_rows <- vector("list", 0L)
  while (isTRUE(reticulate::py_to_r(py_result$has_next()))) {
    all_rows[[length(all_rows) + 1L]] <- py_result$get_next()
  }

  df_list <- lapply(all_rows, function(row) {
    row_values <- reticulate::py_to_r(row)
    stats::setNames(lapply(row_values, convert_python_to_r), col_names)
  })

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
  }

  do.call(rbind, lapply(df_list, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  }))
}

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
#'   db <- attr(conn_disk, "lbugr_db")
#'   if (!is.null(db)) {
#'     db$shutdown()
#'   }
#'   unlink(temp_db_dir, recursive = TRUE)
#' })
#' }
lb_connection <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single non-NA character string.", call. = FALSE)
  }

  # Use the globally initialized lbugr object (from zzz.R)
  # This handles both 'ladybug' and 'real_ladybug' package names
  lb <- lbugr

  main <- reticulate::import_main(convert = FALSE)
  main$lb <- lb
  main$lbugr_path <- path
  reticulate::py_run_string("db = lb.Database(lbugr_path)\nconn = lb.Connection(db)", convert = FALSE)

  db <- main$db
  conn <- main$conn
  attr(conn, "lbugr_db") <- db
  conn
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
  if (!inherits(conn, "python.builtin.object")) {
    stop("`conn` must be a Ladybug connection object from lb_connection().", call. = FALSE)
  }
  if (!is.character(query) || length(query) != 1L || is.na(query)) {
    stop("`query` must be a single non-NA character string.", call. = FALSE)
  }

  result <- conn$execute(query)
  query_result_to_df(result)
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
  query_result_to_df(x)
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
  tibble::as_tibble(query_result_to_df(x))
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
  if (is.data.frame(result)) {
    lapply(seq_len(nrow(result)), function(i) {
      as.list(result[i, , drop = FALSE])
    })
  } else {
    col_names <- reticulate::py_to_r(result$get_column_names())
    all_rows_values <- vector("list", 0L)
    while (result$has_next()) {
      all_rows_values[[length(all_rows_values) + 1L]] <- result$get_next()
    }
    lapply(all_rows_values, function(row) {
      stats::setNames(lapply(row, convert_python_to_r), col_names)
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
#' @importFrom utils head
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
    col_names <- reticulate::py_to_r(result$get_column_names())
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
  if (is.data.frame(result)) {
    cache_key <- digest::sha1(paste(deparse(result), collapse = ""))
    iter_pos <- .lbugr_iter_cache[[cache_key]]
    if (is.null(iter_pos)) {
      iter_pos <- 1
    }

    if (iter_pos > nrow(result)) {
      rm(list = cache_key, envir = .lbugr_iter_cache)
      return(NULL)
    }

    row <- as.list(result[iter_pos, ])
    .lbugr_iter_cache[[cache_key]] <- iter_pos + 1

    return(row)
  }

  if (!result$has_next()) {
    return(NULL)
  }
  col_names <- result$get_column_names()
  row_values <- result$get_next()
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