# Graph viewer: schema parsing (ported from the metadata-mesh-viewer).
#
# Pure functions (no HTTP, no Shiny). `parse_schema()` normalizes a
# `/schema`-shaped document (node_tables / rel_tables) into the schema map
# consumed by `generate_graph_query()` and `rows_to_graph()`.

#' Parse a parsed `/schema`-shaped JSON document into nodes and rels.
#'
#' @param schema_json List (parsed JSON) with `node_tables` and `rel_tables`.
#' @return `list(nodes = <named list>, rels = <named list>)` where
#'   `nodes[[name]]` is `list(name, pk, label_cols, columns, count)` and
#'   `rels[[name]]` is `list(name, from, to, from_pk, to_pk, count)`.
#' @keywords internal
parse_schema <- function(schema_json) {
  check_schema_json(schema_json)

  nodes <- list()
  for (tbl in schema_json$node_tables) {
    cols <- tbl$columns
    pk_flags <- vapply(cols, function(col) isTRUE(col[["primary key"]]), logical(1))
    if (sum(pk_flags) != 1L) {
      rlang::abort(sprintf(
        "Node table '%s' must have exactly one primary key column (found %d).",
        tbl$name, sum(pk_flags)
      ))
    }
    pk <- cols[[which(pk_flags)[[1]]]]$name
    label_cols <- detect_label_cols(cols, pk)
    nodes[[tbl$name]] <- list(
      name = tbl$name,
      pk = pk,
      label_cols = label_cols,
      columns = data.frame(
        name = vapply(cols, function(col) col[["name"]], character(1)),
        type = vapply(cols, function(col) col[["type"]], character(1)),
        primary_key = pk_flags,
        stringsAsFactors = FALSE
      ),
      count = as.integer(tbl$count)
    )
  }

  rels <- list()
  for (tbl in schema_json$rel_tables) {
    conns <- tbl$connection
    if (length(conns) != 1L) {
      rlang::abort(sprintf(
        "Rel table '%s' must have exactly one connection (found %d).",
        tbl$name, length(conns)
      ))
    }
    conn <- conns[[1]]
    check_rel_conn(tbl$name, conn)
    if (is.null(nodes[[conn$from]])) {
      rlang::abort(sprintf("Rel table '%s': unknown from-table '%s'.", tbl$name, conn$from))
    }
    if (is.null(nodes[[conn$to]])) {
      rlang::abort(sprintf("Rel table '%s': unknown to-table '%s'.", tbl$name, conn$to))
    }
    rels[[tbl$name]] <- list(
      name = tbl$name,
      from = conn$from,
      to = conn$to,
      from_pk = conn$from_pk,
      to_pk = conn$to_pk,
      count = as.integer(tbl$count)
    )
  }

  list(nodes = nodes, rels = rels)
}

check_schema_json <- function(schema_json) {
  if (!is.list(schema_json)) {
    rlang::abort("schema_json must be a parsed JSON object (list).")
  }
  if (!is.list(schema_json$node_tables) || !is.list(schema_json$rel_tables)) {
    rlang::abort("schema_json must contain 'node_tables' and 'rel_tables' lists.")
  }
  for (tbl in schema_json$node_tables) {
    if (!is.list(tbl) || !rlang::is_string(tbl$name) || !nzchar(tbl$name)) {
      rlang::abort("Every node table must be a list with a non-empty 'name'.")
    }
    if (!is.list(tbl$columns) || length(tbl$columns) == 0L) {
      rlang::abort(sprintf("Node table '%s' must have a non-empty 'columns' list.", tbl$name))
    }
  }
  for (tbl in schema_json$rel_tables) {
    if (!is.list(tbl) || !rlang::is_string(tbl$name) || !nzchar(tbl$name)) {
      rlang::abort("Every rel table must be a list with a non-empty 'name'.")
    }
    if (!is.list(tbl$connection) || length(tbl$connection) == 0L) {
      rlang::abort(sprintf("Rel table '%s' must have a non-empty 'connection' list.", tbl$name))
    }
  }
  node_names <- vapply(schema_json$node_tables, `[[`, character(1), "name")
  if (anyDuplicated(node_names)) {
    rlang::abort("Duplicate node table names in /schema.")
  }
  rel_names <- vapply(schema_json$rel_tables, `[[`, character(1), "name")
  if (anyDuplicated(rel_names)) {
    rlang::abort("Duplicate rel table names in /schema.")
  }
  invisible(NULL)
}

#' Fetch the schema of a local LadybugDB connection in `/schema` shape.
#'
#' Uses the catalog helpers of the installed ladybug Python driver
#' (`_get_node_table_names` / `_get_rel_table_names` /
#' `_get_node_property_names` on the Connection) plus count queries via
#' public Cypher. Returns the same shape the reference app's
#' `GET /api/v1/schema` endpoint served, so `parse_schema()` consumes it
#' unchanged. Verified against a local seeded DB (plan D7).
#'
#' @param conn A Ladybug connection object from `lb_connection()`.
#' @return A list with `node_tables` (name, count, columns) and
#'   `rel_tables` (name, count, connection).
#' @keywords internal
viewer_fetch_schema <- function(conn) {
  if (!inherits(conn, "python.builtin.object")) {
    rlang::abort("`conn` must be a Ladybug connection object from lb_connection().")
  }

  node_names <- viewer_catalog(conn, "_get_node_table_names")
  rel_infos <- viewer_catalog(conn, "_get_rel_table_names")
  props <- stats::setNames(
    lapply(node_names, function(t) viewer_catalog(conn, "_get_node_property_names", t)),
    node_names
  )

  pk_of <- function(t) {
    flags <- vapply(props[[t]], function(p) isTRUE(p$is_primary_key), logical(1))
    if (sum(flags) != 1L) {
      rlang::abort(sprintf(
        "Node table '%s' must have exactly one primary key column (found %d).",
        t, sum(flags)
      ))
    }
    names(props[[t]])[which(flags)[[1L]]]
  }
  count_query <- function(q) {
    as.integer(lb_execute(conn, q)$cnt[[1L]])
  }

  node_tables <- lapply(node_names, function(t) {
    list(
      name = t,
      count = count_query(paste0("MATCH (n:", t, ") RETURN count(n) AS cnt")),
      columns = lapply(names(props[[t]]), function(cn) {
        list(
          name = cn,
          type = props[[t]][[cn]]$type,
          `primary key` = isTRUE(props[[t]][[cn]]$is_primary_key)
        )
      })
    )
  })
  rel_tables <- lapply(rel_infos, function(ri) {
    list(
      name = ri$name,
      count = count_query(paste0("MATCH ()-[r:", ri$name, "]->() RETURN count(r) AS cnt")),
      connection = list(list(
        from = ri$src, from_pk = pk_of(ri$src),
        to = ri$dst, to_pk = pk_of(ri$dst)
      ))
    )
  })

  list(node_tables = node_tables, rel_tables = rel_tables)
}

#' Call a private ladybug catalog helper with a clear failure message.
viewer_catalog <- function(conn, fn, ...) {
  tryCatch(
    reticulate::py_to_r(conn[[fn]](...)),
    error = function(e) {
      rlang::abort(
        paste0(
          sprintf(
            "The installed 'ladybug' Python package does not expose the catalog helper '%s' (%s).\n",
            fn, conditionMessage(e)
          ),
          "This lbugr version requires it for the graph viewer. Try: reticulate::py_install('ladybug', pip = TRUE)"
        ),
        call. = FALSE
      )
    }
  )
}
#' Ordered label candidates: `label`, first `bezeichnung_*`, then primary key.
detect_label_cols <- function(cols, pk) {
  names <- vapply(cols, function(col) col[["name"]], character(1))
  cands <- character(0)
  if ("label" %in% names) cands <- c(cands, "label")
  bez <- names[startsWith(names, "bezeichnung_")]
  if (length(bez) >= 1L) cands <- c(cands, bez[[1]])
  c(unique(c(cands, pk)))
}

check_rel_conn <- function(tbl_name, conn) {
  for (field in c("from", "to", "from_pk", "to_pk")) {
    if (!rlang::is_string(conn[[field]]) || !nzchar(conn[[field]])) {
      rlang::abort(sprintf(
        "Rel table '%s': connection field '%s' must be a non-empty string.",
        tbl_name, field
      ))
    }
  }
  invisible(NULL)
}
