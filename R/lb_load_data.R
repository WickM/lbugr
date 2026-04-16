# Data Loading Functions for lbugr

# Validate that a table name is a safe Cypher identifier.
# Prevents Cypher injection via malformed table names.
validate_table_name <- function(table_name) {
  if (!is.character(table_name) || length(table_name) != 1L ||
      !grepl("^[A-Za-z_][A-Za-z0-9_]*$", table_name)) {
    stop(
      "table_name must be a valid identifier (letters, digits, underscores only).",
      call. = FALSE
    )
  }
}

#' Load Data from a Data Frame or Tibble into a Ladybug Table
#'
#' Efficiently copies data from an R `data.frame` or `tibble` into a specified
#' table in the Ladybug database.
#'
#' When loading into a relationship table, Ladybug assumes the first two columns
#' in the file are:
#' FROM Node Column: The primary key of the FROM nodes.
#' TO Node Column: The primary key of the TO nodes.
#'
#' @param conn A Ladybug connection object.
#' @param df A `data.frame` or `tibble` containing the data to load. Column
#'   names in the data frame should match the property names in the Ladybug table.
#' @param table_name A string specifying the name of the destination table in
#' Ladybug.
#' @return This function is called for its side effect of loading data and does
#'   not return a value.
#' @export
#' @examples
#' \donttest{
#'   conn <- lb_connection(":memory:")
#'   lb_execute(conn, "CREATE NODE TABLE User(name STRING, age INT64,
#'   PRIMARY KEY (name))")
#'   lb_execute(conn, "CREATE REL TABLE Knows(FROM User TO User)")
#'
#'   # Load from a data.frame
#'   users_df <- data.frame(name = c("Carol", "Dan"), age = c(35, 40))
#'   lb_copy_from_df(conn, users_df, "User")
#'
#'   # Load from a tibble (requires pre-existing nodes)
#'   lb_execute(conn, "CREATE (u:User {name: 'Alice'}), (v:User {name: 'Bob'})")
#'   knows_df <- data.frame(from_person = c("Alice", "Bob"),
#'   to_person = c("Bob", "Carol"))
#'   lb_copy_from_df(conn, knows_df, "Knows")
#'
#'   result <- lb_execute(conn, "MATCH (a:User) RETURN a.name, a.age")
#'   print(as.data.frame(result))
#'
#'   result_rel <- lb_execute(conn, "MATCH (a:User)-[k:Knows]->(b:User)
#'   RETURN a.name, b.name")
#'   print(as.data.frame(result_rel))
#' }
#' @seealso \href{https://docs.ladybugdb.com/docs/import/copy-from-dataframe}{Ladybug Copy from DataFrame}
lb_copy_from_df <- function(conn, df, table_name) {
  validate_table_name(table_name)

  # Coerce factor columns to character, as they are not directly supported by Ladybug
  df[] <- lapply(df, function(x) {
    if (is.factor(x)) as.character(x) else x
  })

  # Create temporary CSV file and ensure it is cleaned up even on error
  temp_file <- tempfile(fileext = ".csv")
  on.exit(if (file.exists(temp_file)) file.remove(temp_file), add = TRUE)

  # Replace NA values with empty strings for Ladybug compatibility
  # Ladybug doesn't support NA in DOUBLE/INT columns - empty string becomes NULL
  df_clean <- lapply(df, function(col) {
    if (is.numeric(col)) {
      ifelse(is.na(col), "", col)
    } else {
      col
    }
  })
  df_clean <- as.data.frame(df_clean, stringsAsFactors = FALSE)

  # Write data frame to CSV without row names
  utils::write.csv(df_clean, file = temp_file, row.names = FALSE)

  # Convert Windows backslashes to forward slashes for Ladybug compatibility
  temp_file_escaped <- gsub("\\\\", "/", temp_file)

  # Use COPY FROM CSV to load data - avoids Python dependency
  query <- paste0(
    "COPY ",
    table_name,
    " FROM '",
    temp_file_escaped,
    "' (header=true)"
  )

  lb_execute(conn, query)

  invisible(NULL)
}

# Copy from file internal Function
# This is an internal helper function and not intended for direct user use.
# It handles the core logic of copying data from a file path.
lb_copy_from_file <- function(
  conn,
  file_path,
  table_name,
  optional_parameter = NULL
) {
  validate_table_name(table_name)

  file_path <- gsub("\\\\", "/", file_path)

  query <- paste0("COPY ", table_name, " FROM '", file_path, "'")

  if (!is.null(optional_parameter)) {
    opts <- paste(
      names(optional_parameter),
      "=",
      unlist(optional_parameter),
      collapse = ", "
    )
    query <- paste0(query, " (", opts, ")")
  }

  conn$execute(query)
  invisible(NULL)
}

#' Create a Ladybug Table from a Data Frame
#'
#' Infers a schema from an R `data.frame` or `tibble` and creates a corresponding
#' NODE table in the Ladybug database.
#'
#' @param conn A Ladybug connection object.
#' @param df A `data.frame` or `tibble` from which to infer the schema.
#' @param table_name A string specifying the name of the new table in Ladybug.
#' @param primary_key An optional string specifying the column to be used as the
#'   primary key. If not provided, no primary key will be set.
#' @return This function is called for its side effect of creating a table and
#'   does not return a value.
#' @export
#' @examples
#' \donttest{
#'   conn <- lb_connection(":memory:")
#'
#'   my_df <- data.frame(
#'     name = c("Alice", "Bob"),
#'     age = c(25L, 30L),
#'     height = c(1.75, 1.80),
#'     is_student = c(TRUE, FALSE),
#'     birth_date = as.Date(c("1999-01-01", "1994-05-15"))
#'   )
#'
#'   lb_create_table_from_df(conn, my_df, "Person", primary_key = "name")
#'
#'   # Now you can load data into the created table
#'   lb_copy_from_df(conn, my_df, "Person")
#'
#'   result <- lb_execute(conn, "MATCH (p:Person) RETURN *")
#'   print(as.data.frame(result))
#' }
lb_create_table_from_df <- function(conn, df, table_name, primary_key) {
  validate_table_name(table_name)

  # Validate column names to prevent Cypher injection
  invalid_cols <- names(df)[!grepl("^[A-Za-z_][A-Za-z0-9_]*$", names(df))]
  if (length(invalid_cols) > 0) {
    stop(
      paste("Invalid column names:", paste(invalid_cols, collapse = ", ")),
      call. = FALSE
    )
  }

  # Helper function to map R types to Ladybug types
  map_type <- function(type) {
    switch(
      type,
      "integer" = "INT64",
      "numeric" = "DOUBLE",
      "character" = "STRING",
      "logical" = "BOOLEAN",
      "Date" = "DATE",
      "factor" = {
        warning("Coercing 'factor' to 'STRING'.")
        "STRING"
      },
      {
        warning(paste("Unsupported R type:", type, ". Defaulting to STRING."))
        "STRING"
      }
    )
  }

  # Get column names and types from the data frame
  col_names <- names(df)
  col_types <- sapply(df, function(x) class(x)[1])

  # Check if the primary key exists in the data frame
  if (!primary_key %in% col_names) {
    stop(paste(
      "Primary key '",
      primary_key,
      "' not found in data frame.",
      sep = ""
    ))
  }

  # Generate column definitions for the CREATE TABLE query
  col_defs <- mapply(
    function(name, type) {
      paste0(name, " ", map_type(type))
    },
    col_names,
    col_types
  )

  # Add the primary key definition
  pk_def <- paste0("PRIMARY KEY (", primary_key, ")")
  all_defs <- c(col_defs, pk_def)

  # Construct the full CREATE TABLE query
  query <- paste0(
    "CREATE NODE TABLE ",
    table_name,
    "(",
    paste(all_defs, collapse = ", "),
    ")"
  )

  # Execute the query
  lb_execute(conn, query)

  invisible(NULL)
}

#' Load Data from a CSV File into a Ladybug Table
#'
#' Loads data from a CSV file into a specified table in the Ladybug database.
#'
#' @param conn A Ladybug connection object.
#' @param file_path A string specifying the path to the CSV file.
#' @param table_name A string specifying the name of the destination table in
#' Ladybug.
#' @param optional_csv_parameter An optional parameter for CSV-specific
#'   configurations (e.g., delimiter, header).
#'   Refer to Ladybug documentation for available options.
#' @return This function is called for its side effect of loading data and does
#'   not return a value.
#' @export
#' @examples
#' \donttest{
#'   conn <- lb_connection(":memory:")
#'   lb_execute(conn, "CREATE NODE TABLE City(name STRING, population INT64,
#'   PRIMARY KEY (name))")
#'
#'   # Create a temporary CSV file
#'   csv_file <- tempfile(fileext = ".csv")
#'   write.csv(data.frame(name = c("Berlin", "London"),
#'   population = c(3645000, 8982000)),
#'             csv_file, row.names = FALSE)
#'
#'   # Load data from CSV
#'   lb_copy_from_csv(conn, csv_file, "City")
#'
#'   # Verify the data
#'   result <- lb_execute(conn, "MATCH (c:City) RETURN c.name, c.population")
#'   print(as.data.frame(result))
#'
#'   # Clean up the temporary file
#'   unlink(csv_file)
#' }
#' @seealso \href{https://docs.ladybugdb.com/docs/import/csv}{Ladybug CSV Import}
lb_copy_from_csv <- function(
  conn,
  file_path,
  table_name,
  optional_csv_parameter = NULL
) {
  lb_copy_from_file(
    conn,
    file_path = file_path,
    table_name = table_name,
    optional_parameter = optional_csv_parameter
  )
}

#' Load Data from a JSON File into a Ladybug Table
#'
#' Loads data from a JSON file into a specified table in the Ladybug database.
#' This function also ensures the JSON extension is loaded and available.
#'
#' @param conn A Ladybug connection object.
#' @param file_path A string specifying the path to the JSON file.
#' @param table_name A string specifying the name of the destination table in
#' Ladybug.
#' @return This function is called for its side effect of loading data and does
#'   not return a value.
#' @export
#' @examples
#' \donttest{
#'   conn <- lb_connection(":memory:")
#'   lb_execute(conn, "CREATE NODE TABLE Product(id INT64, name STRING,
#'   PRIMARY KEY (id))")
#'
#'   # Create a temporary JSON file
#'   json_file <- tempfile(fileext = ".json")
#'   json_data <- '[{"id": 1, "name": "Laptop"}, {"id": 2, "name": "Mouse"}]'
#'   writeLines(json_data, json_file)
#'
#'   # Load data from JSON
#'   lb_copy_from_json(conn, json_file, "Product")
#'
#'   # Verify the data
#'   result <- lb_execute(conn, "MATCH (p:Product) RETURN p.id, p.name")
#'   print(as.data.frame(result))
#'
#'   # Clean up the temporary file
#'   unlink(json_file)
#' }
#' @seealso \href{https://docs.ladybugdb.com/docs/import/copy-from-json}{Ladybug JSON Import}, \href{https://docs.ladybugdb.com/docs/extensions/json}{Ladybug JSON Extension}
lb_copy_from_json <- function(conn, file_path, table_name) {
  # Ensure the JSON extension is installed and loaded
  tryCatch(
    {
      lb_execute(conn, query = "INSTALL json;LOAD json;")
    },
    error = function(e) {
      warning(
        paste(
          "Could not install or load JSON extension. Please check your",
          "internet connection and Ladybug setup."
        )
      )
    }
  )
  # Use the internal copy function to load data from the JSON file
  lb_copy_from_file(conn, file_path = file_path, table_name = table_name)
}

#' Load Data from a Parquet File into a Ladybug Table
#'
#' Loads data from a Parquet file into a specified table in the Ladybug database.
#'
#' @param conn A Ladybug connection object.
#' @param file_path A string specifying the path to the Parquet file.
#' @param table_name A string specifying the name of the destination table in
#' Ladybug.
#' @return This function is called for its side effect of loading data and does
#'   not return a value.
#' @export
#' @examples
#' \donttest{
#'   if (requireNamespace("arrow", quietly = TRUE)) {
#'     conn <- lb_connection(":memory:")
#'     lb_execute(conn, "CREATE NODE TABLE Country(name STRING, code STRING,
#'     PRIMARY KEY (name))")
#'
#'     # Create a temporary Parquet file
#'     parquet_file <- tempfile(fileext = ".parquet")
#'     country_df <- data.frame(name = c("USA", "Canada"), code = c("US", "CA"))
#'     arrow::write_parquet(country_df, parquet_file)
#'
#'     # Load data from Parquet
#'     lb_copy_from_parquet(conn, parquet_file, "Country")
#'
#'     # Verify the data
#'     result <- lb_execute(conn, "MATCH (c:Country) RETURN c.name, c.code")
#'     print(as.data.frame(result))
#'
#'     # Clean up the temporary file
#'     unlink(parquet_file)
#'   }
#' }
#' @seealso \href{https://docs.ladybugdb.com/docs/import/parquet}{Ladybug Parquet Import}
lb_copy_from_parquet <- function(conn, file_path, table_name) {
  # Use the internal copy function to load data from the Parquet file
  lb_copy_from_file(conn, file_path = file_path, table_name = table_name)
}

#' Merge Data from a Data Frame into Ladybug using a Merge Query
#'
#' This function is intended for merging data from an R `data.frame` into Ladybug
#' using a specified merge query.
#'
#' @param conn A Ladybug connection object.
#' @param df A `data.frame` or `tibble` containing the data to merge.
#' @param merge_query A string representing the Ladybug query for merging data.
#' @return This function is called for its side effect of merging data and does
#'   not return a value.
#' @export
#' @examples
#' \dontrun{
#' my_data <- data.frame(
#'    name = c("Alice", "Bob"),
#'    item = c("Book", "Pen"),
#'    current_city = c("New York", "London")
#'  )
#'
#'  merge_statement <- "MERGE (p:Person {name: df.name})
#'  MERGE (i:Item {name: df.item})
#'  MERGE (p)-[:PURCHASED]->(i)
#'  ON MATCH SET p.current_city = df.current_city
#'  ON CREATE SET p.current_city = df.current_city"
#'
#'  # Note: 'conn' would need to be a valid Ladybug connection object
#'  # and the schema (Person, Item, PURCHASED tables) would need to be created
#'  # before running this example.
#'  # lb_merge_df(conn, my_data, merge_statement)
#'
#'  # Example with a different merge query structure:
#'  my_data_2 <- data.frame(
#'    person_name = c("Charlie"),
#'    purchased_item = c("Laptop"),
#'    city = c("Paris")
#'  )
#' #
#'  merge_statement_2 <- "MERGE (p:Person {name: person_name})
#'  MERGE (i:Item {name: purchased_item})
#'  MERGE (p)-[:PURCHASED]->(i)
#'  ON MATCH SET p.current_city = city
#'  ON CREATE SET p.current_city = city"
#'
#'  # lb_merge_df(conn, my_data_2, merge_statement_2)
#'  }
#' @seealso \href{https://docs.ladybugdb.com/docs/import/copy-from-dataframe}{Ladybug Copy from DataFrame}
lb_merge_df <- function(conn, df, merge_query) {
  if (!is.character(merge_query) || length(merge_query) != 1L || !nzchar(merge_query)) {
    stop("`merge_query` must be a non-empty Cypher query string.", call. = FALSE)
  }

  # Create temporary CSV file - avoids pandas dependency from LOAD FROM df
  temp_file <- tempfile(fileext = ".csv")
  on.exit(if (file.exists(temp_file)) file.remove(temp_file), add = TRUE)

  # Handle NA values similar to lb_copy_from_df
  df_clean <- lapply(df, function(col) {
    if (is.numeric(col)) {
      ifelse(is.na(col), "", col)
    } else {
      col
    }
  })
  df_clean <- as.data.frame(df_clean, stringsAsFactors = FALSE)

  # Write to CSV
  utils::write.csv(df_clean, file = temp_file, row.names = FALSE)

  # Convert Windows backslashes to forward slashes for Ladybug compatibility
  temp_file_escaped <- gsub("\\\\", "/", temp_file)

  # Use LOAD FROM CSV file instead of LOAD FROM df (avoids pandas)
  query <- paste0("LOAD FROM '", temp_file_escaped, "' ", merge_query)
  lb_execute(conn, query)

  invisible(NULL)
}