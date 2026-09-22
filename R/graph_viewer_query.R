# Graph viewer: Cypher generation + query execution against a local
# LadybugDB connection (ported from the metadata-mesh-viewer, where the
# HTTP layer was replaced by direct `lb_execute()` calls).

#' Build the full-graph Cypher query for a schema map.
#'
#' One `UNION` branch per node table and per rel table; every branch
#' returns the uniform row shape `{type, id, label, source, target}`
#' (NULL where not applicable). LadybugDB requires consistent column
#' types across UNION branches, so absent values are typed with
#' `CAST(NULL AS STRING)`. Syntax verified live against LadybugDB
#' (reference app, 2026-09-11).
#'
#' @param schema_map Output of `parse_schema()`.
#' @return A single deterministic Cypher string; branches are joined by
#'   `"\nUNION\n"`.
#' @keywords internal
generate_graph_query <- function(schema_map) {
  if (!is.list(schema_map$nodes) || !is.list(schema_map$rels)) {
    rlang::abort("schema_map must be the output of parse_schema().")
  }
  branches <- c(
    vapply(names(schema_map$nodes), node_branch, character(1), schema_map = schema_map),
    vapply(names(schema_map$rels), rel_branch, character(1), schema_map = schema_map)
  )
  if (length(branches) == 0L) {
    rlang::abort("Cannot generate a query for an empty schema map (no node or rel tables).")
  }
  paste(branches, collapse = "\nUNION\n")
}

node_branch <- function(name, schema_map) {
  tbl <- schema_map$nodes[[name]]
  check_cypher_identifier("node table", name)
  check_cypher_identifier("primary key", tbl$pk)
  check_cypher_identifier("label column", tbl$label_cols)
  label_expr <- paste0("n.", tbl$label_cols, collapse = ", ")
  if (length(tbl$label_cols) > 1L) {
    label_expr <- paste0("coalesce(", label_expr, ")")
  }
  paste0(
    "MATCH (n:", name, ")\n",
    "RETURN '", name, "' AS type, n.", tbl$pk, " AS id, ",
    label_expr, " AS label, CAST(NULL AS STRING) AS source, ",
    "CAST(NULL AS STRING) AS target"
  )
}

rel_branch <- function(name, schema_map) {
  rel <- schema_map$rels[[name]]
  check_cypher_identifier("rel table", rel$name)
  check_cypher_identifier("from table", rel$from)
  check_cypher_identifier("to table", rel$to)
  check_cypher_identifier("from primary key", rel$from_pk)
  check_cypher_identifier("to primary key", rel$to_pk)
  paste0(
    "MATCH (a:", rel$from, ")-[r:", rel$name, "]->(b:", rel$to, ")\n",
    "RETURN '", rel$name, "' AS type, CAST(NULL AS STRING) AS id, ",
    "CAST(NULL AS STRING) AS label, a.", rel$from_pk, " AS source, b.",
    rel$to_pk, " AS target"
  )
}

check_cypher_identifier <- function(what, value) {
  value <- unlist(value)
  # Deviation from the reference (D10): local DBs commonly use CamelCase
  # table names; allow ASCII letters (injection still impossible).
  bad <- !grepl("^[A-Za-z][A-Za-z0-9_]*$", value)
  if (any(bad)) {
    rlang::abort(sprintf(
      "Invalid Cypher identifier for %s: '%s' (expected [A-Za-z][A-Za-z0-9_]*).",
      what, value[which(bad)[[1L]]]
    ))
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Local query execution (replaces the reference app's HTTP client)
# ---------------------------------------------------------------------------

#' Write keywords blocked in viewer free queries (client-side blocklist).
#'
#' The reference app enforced this in its Python backend (400 + message);
#' lbugr has no backend, so the check runs client-side before execution.
#' Word-boundary matching: `created_at` (a property name) must NOT match.
#' @keywords internal
viewer_blocked_keywords <- function() {
  c("DROP", "DELETE", "CREATE", "ALTER", "DETACH", "MERGE")
}

#' Check a free query against the write-keyword blocklist.
#'
#' @param query A single Cypher query string.
#' @return Invisible NULL on success; aborts with a "blocked keyword" error
#'   otherwise.
#' @keywords internal
viewer_check_query <- function(query) {
  if (!rlang::is_string(query) || !nzchar(query)) {
    rlang::abort("query must be a single non-empty string.")
  }
  kw <- paste(viewer_blocked_keywords(), collapse = "|")
  m <- regexec(paste0("\\b(?:", kw, ")\\b"), toupper(query), perl = TRUE)
  hit <- regmatches(query, m)[[1L]]
  # No match: regmatches returns character(0).
  if (length(hit) > 0L && nzchar(hit)) {
    rlang::abort(sprintf(
      "Query contains blocked keyword: %s. Only read-only queries are allowed.",
      hit
    ))
  }
  invisible(NULL)
}

#' Execute a Cypher query on a local connection and return uniform rows.
#'
#' Shaped like the reference app's `run_query()`: `results` is a list of row
#' lists (column names as names), `row_count` the number of rows. Node and
#' relationship values are flattened into their property fields
#' (`n.name`, `r._LABEL`, ...), which is what `rows_to_graph()` /
#' `rows_to_df()` consume via the uniform `{type, id, label, source, target}`
#' shape produced by `generate_graph_query()`.
#'
#' @param conn A Ladybug connection from `lb_connection()`.
#' @param query A single Cypher query string (read-only; the blocklist in
#'   `viewer_check_query()` is applied first).
#' @return `list(results = <list of row lists>, row_count = <integer>)`.
#' @keywords internal
viewer_run_query <- function(conn, query) {
  viewer_check_query(query)
  df <- lb_execute(conn, query)
  results <- lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
  list(results = results, row_count = as.integer(nrow(df)))
}
