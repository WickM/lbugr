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
#' @return An external pointer to the Ladybug database connection.
#' @export
#' @examples
#' \dontrun{
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
#' }
lb_connection <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single non-NA character string.", call. = FALSE)
  }
  
  conn <- lbug_connect(path)
  class(conn) <- c("lbugr_connection", class(conn))
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
#' @return A data.frame containing the query results.
#' @export
#' @examples
#' \dontrun{
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
  if (!inherits(conn, "lbugr_connection")) {
    stop("`conn` must be a Ladybug connection object from lb_connection().", call. = FALSE)
  }
  if (!is.character(query) || length(query) != 1L || is.na(query)) {
    stop("`query` must be a single non-NA character string.", call. = FALSE)
  }
  
  lbug_execute(conn, query)
}

#' Retrieve All Rows from a Query Result
#'
#' Fetches all rows from a Ladybug query result and returns them as a list of
#' lists.
#'
#' @param result A data.frame from `lb_execute()`.
#' @return A list where each element is a list representing a row of results.
#' @export
#' @examples
#' \dontrun{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' all_results <- lb_get_all(result)
#' }
lb_get_all <- function(result) {
  if (!is.data.frame(result)) {
    stop("`result` must be a data.frame from lb_execute().", call. = FALSE)
  }
  
  lapply(seq_len(nrow(result)), function(i) {
    as.list(result[i, , drop = FALSE])
  })
}

#' Retrieve the First N Rows from a Query Result
#'
#' Fetches the first `n` rows from a Ladybug query result.
#'
#' @param result A data.frame from `lb_execute()`.
#' @param n The number of rows to retrieve.
#' @return A list of the first `n` rows.
#' @importFrom utils head
#' @export
#' @examples
#' \dontrun{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' lb_execute(conn, "CREATE (:User {name: 'Bob', age: 30})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' first_row <- lb_get_n(result, 1)
#' }
lb_get_n <- function(result, n) {
  if (!is.data.frame(result)) {
    stop("`result` must be a data.frame from lb_execute().", call. = FALSE)
  }
  
  head_rows <- head(result, n)
  lapply(seq_len(nrow(head_rows)), function(i) {
    as.list(head_rows[i, , drop = FALSE])
  })
}

#' Retrieve the Next Row from a Query Result
#'
#' Fetches the next available row from a Ladybug query result. This function can be
#' called repeatedly to iterate through results one by one.
#'
#' @param result A data.frame from `lb_execute()`.
#' @return A list representing the next row, or `NULL` if no more rows are
#' available.
#' @export
#' @examples
#' \dontrun{
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
  if (!is.data.frame(result)) {
    stop("`result` must be a data.frame from lb_execute().", call. = FALSE)
  }
  
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

#' Get Column Data Types from a Query Result
#'
#' Retrieves the data types of the columns in a Ladybug query result.
#'
#' @param result A data.frame from `lb_execute()`.
#' @return A character vector of column data types.
#' @export
#' @examples
#' \dontrun{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' lb_get_column_data_types(result)
#' }
lb_get_column_data_types <- function(result) {
  if (!is.data.frame(result)) {
    stop("`result` must be a data.frame from lb_execute().", call. = FALSE)
  }
  
  sapply(result, function(x) typeof(x))
}

#' Get Column Names from a Query Result
#'
#' Retrieves the names of the columns in a Ladybug query result.
#'
#' @param result A data.frame from `lb_execute()`.
#' @return A character vector of column names.
#' @export
#' @examples
#' \dontrun{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' lb_get_column_names(result)
#' }
lb_get_column_names <- function(result) {
  if (!is.data.frame(result)) {
    stop("`result` must be a data.frame from lb_execute().", call. = FALSE)
  }
  
  names(result)
}

#' Get Schema from a Query Result
#'
#' Retrieves the schema (column names and data types) of a Ladybug query result.
#'
#' @param result A data.frame from `lb_execute()`.
#' @return A named character vector where names are column names and values are data types.
#' @export
#' @examples
#' \dontrun{
#' conn <- lb_connection(":memory:")
#' lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#' PRIMARY KEY (name))")
#' lb_execute(conn, "CREATE (:User {name: 'Alice', age: 25})")
#' result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#' lb_get_schema(result)
#' }
lb_get_schema <- function(result) {
  if (!is.data.frame(result)) {
    stop("`result` must be a data.frame from lb_execute().", call. = FALSE)
  }
  
  setNames(sapply(result, function(x) typeof(x)), names(result))
}
