# Graph viewer: graph model (ported from the metadata-mesh-viewer).
#
# Pure functions (no HTTP, no Shiny). Input rows come from
# `viewer_run_query()$results` — uniform shape `{type, id, label, source,
# target}` with NULL where not applicable. Node rows carry `id`, edge rows
# carry `source`/`target`. Node ids are globally prefixed `<type>:<pk>` so
# that equal primary keys in different tables never collide in g6R.

node_palette <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728",
  "#9467bd", "#8c564b", "#e377c2", "#17becf",
  "#bcbd22", "#7f7f7f"
)

#' Build graph data + table rows from uniform query rows.
#'
#' @param rows List of row lists (`viewer_run_query()$results`), each with
#'   `type`, `id`, `label`, `source`, `target` (NULL where not applicable).
#' @param schema_map Output of `parse_schema()` (rel type -> from/to tables).
#' @return `list(nodes = <data.frame id,label,type,color>,
#'   edges = <data.frame id,source,target,rel_type>,
#'   table = <data.frame kind,type,id,label,source,target>)`.
#' Rows are deterministically ordered (nodes by id, edges by (rel,source,target),
#' table: nodes then edges by id, type colors by sorted type) — the backend
#' does not guarantee row order, and the g6R layout must be reproducible.
#' @keywords internal
rows_to_graph <- function(rows, schema_map) {
  if (!is.list(rows)) {
    rlang::abort("rows must be a list of row lists (viewer_run_query()$results).")
  }
  if (length(rows) == 0L) {
    return(empty_graph())
  }

  df <- data.frame(
    type = row_field(rows, "type"),
    id = row_field(rows, "id"),
    label = row_field(rows, "label"),
    source = row_field(rows, "source"),
    target = row_field(rows, "target"),
    stringsAsFactors = FALSE
  )
  is_node <- !is.na(df$id)
  is_edge <- !is.na(df$source) & !is.na(df$target)
  if (any(!is_node & !is_edge)) {
    rlang::abort("Every row must be a node row (id) or an edge row (source+target).")
  }
  if (any(is_node & is_edge)) {
    rlang::abort("A row cannot be both a node row and an edge row.")
  }

  # Node ids: globally unique <type>:<pk>
  node_id <- rep(NA_character_, nrow(df))
  node_id[is_node] <- paste0(df$type[is_node], ":", df$id[is_node])

  # Edge source/target ids resolved via the schema map (rel -> from/to table).
  # Edge rows sorted by content key so duplicate-id suffixes (`:n`) and the
  # layout input order do not depend on the backend's row order. Guarded:
  # `paste0` with the literal "|" separators returns length 1 even when the
  # indexed columns are empty, so a node-only (zero-edge) query would reindex
  # `integer(0)[1]` to `NA`. Skip the reindex when there are no edges.
  edge_idx <- which(is_edge)
  if (length(edge_idx) > 0L) {
    edge_idx <- edge_idx[order(
      paste0(df$type[edge_idx], "|", df$source[edge_idx], "|", df$target[edge_idx]),
      method = "radix"
    )]
  }
  from_tbl <- rel_from_table(df$type[edge_idx], schema_map)
  to_tbl <- rel_to_table(df$type[edge_idx], schema_map)
  source_id <- rep(NA_character_, nrow(df))
  target_id <- rep(NA_character_, nrow(df))
  source_id[edge_idx] <- paste0(from_tbl, ":", df$source[edge_idx])
  target_id[edge_idx] <- paste0(to_tbl, ":", df$target[edge_idx])

  raw_edge_id <- paste0(source_id[edge_idx], "|", df$type[edge_idx], "|", target_id[edge_idx])
  edge_id <- rep(NA_character_, nrow(df))
  edge_id[edge_idx] <- make_unique(raw_edge_id)

  node_idx <- which(is_node)
  labels <- df$label[node_idx]
  missing <- is.na(labels)
  labels[missing] <- df$id[node_idx][missing]
  node_type_order <- sort(unique(df$type[node_idx]), method = "radix")
  color_of <- node_palette[seq_along(node_type_order)]
  names(color_of) <- node_type_order

  nodes_df <- data.frame(
    id = node_id[node_idx],
    label = labels,
    type = df$type[node_idx],
    color = color_of[df$type[node_idx]],
    stringsAsFactors = FALSE
  )
  nodes_df <- nodes_df[order(nodes_df$id, method = "radix"), , drop = FALSE]
  edges_df <- data.frame(
    id = edge_id[edge_idx],
    source = source_id[edge_idx],
    target = target_id[edge_idx],
    rel_type = df$type[edge_idx],
    stringsAsFactors = FALSE
  )

  row_label <- df$label
  missing_label <- is_node & is.na(df$label)
  row_label[missing_label] <- df$id[missing_label]
  row_label[is.na(row_label)] <- ""
  table_df <- data.frame(
    kind = ifelse(is_node, "node", "edge"),
    type = df$type,
    id = ifelse(is_node, node_id, edge_id),
    label = row_label,
    source = ifelse(is_edge, source_id, ""),
    target = ifelse(is_edge, target_id, ""),
    stringsAsFactors = FALSE
  )
  table_df <- table_df[order(
    paste0(ifelse(table_df$kind == "node", "0:", "1:"), table_df$id),
    method = "radix"
  ), , drop = FALSE]

  list(nodes = nodes_df, edges = edges_df, table = table_df)
}

empty_graph <- function() {
  list(
    nodes = data.frame(
      id = character(), label = character(),
      type = character(), color = character()
    ),
    edges = data.frame(
      id = character(), source = character(),
      target = character(), rel_type = character()
    ),
    table = data.frame(
      kind = character(), type = character(), id = character(),
      label = character(), source = character(), target = character()
    )
  )
}
row_field <- function(rows, field) {
  vapply(rows, function(row) {
    if (!is.list(row)) {
      rlang::abort("Every row must be a list of fields.")
    }
    value <- row[[field]]
    if (is.null(value)) NA_character_ else as.character(value)
  }, character(1))
}

rel_from_table <- function(rel_types, schema_map) {
  vapply(rel_types, function(rel_type) {
    meta <- schema_map$rels[[rel_type]]
    if (is.null(meta)) {
      rlang::abort(sprintf("Unknown rel type in rows: '%s'.", rel_type))
    }
    meta$from
  }, character(1))
}

rel_to_table <- function(rel_types, schema_map) {
  vapply(rel_types, function(rel_type) {
    schema_map$rels[[rel_type]]$to
  }, character(1))
}

#' First occurrence keeps the bare id, later duplicates get `:2`, `:3`, ...
make_unique <- function(ids) {
  out <- character(length(ids))
  seen <- new.env(parent = emptyenv())
  for (i in seq_along(ids)) {
    key <- ids[[i]]
    n <- seen[[key]]
    if (is.null(n)) {
      seen[[key]] <- 1L
      out[[i]] <- key
    } else {
      seen[[key]] <- n + 1L
      out[[i]] <- paste0(key, ":", n + 1L)
    }
  }
  out
}

#' Turn arbitrary query rows into a data frame (free query results).
#'
#' Unlike `rows_to_graph()`, no graph shape is required: the union of all
#' field names becomes the columns (first-seen order); a row missing a field
#' gets NA. Values keep their original type (numbers stay numeric).
#'
#' @param rows List of row lists (`viewer_run_query()$results`).
#' @return Data frame (0 rows for empty input).
#' @keywords internal
rows_to_df <- function(rows) {
  if (!is.list(rows)) {
    rlang::abort("rows must be a list of row lists (viewer_run_query()$results).")
  }
  if (length(rows) == 0L) {
    return(data.frame())
  }
  cols <- unique(unlist(lapply(rows, names)))
  cols <- cols[!is.na(cols)]
  # Columns as plain vectors (data.frame(list(a, b)) would treat the list
  # elements as separate columns). Scalar cells only -- nested objects
  # are flattened by unlist.
  col_values <- lapply(cols, function(nm) {
    unlist(lapply(rows, function(row) {
      if (is.list(row) && !is.null(row[[nm]])) row[[nm]] else NA
    }), use.names = FALSE)
  })
  df <- do.call(data.frame, c(col_values, list(stringsAsFactors = FALSE)))
  names(df) <- cols
  df
}

#' Try to interpret uniform query rows as a graph model (or not).
#'
#' A free query is graph-capable only if its rows follow the uniform
#' `{type, id, label, source, target}` shape and use rel types present in the
#' schema. `rows_to_graph()` aborts on anything else (scalar rows such as
#' `count`, an unknown rel type, or a mixed node/edge row); this wrapper turns
#' that abort into a value so the view can fall back to a plain result table
#' instead of erroring the whole query run.
#'
#' @param rows List of row lists (`viewer_run_query()$results`).
#' @param schema_map Output of `parse_schema()`.
#' @return `list(ok = TRUE, model = rows_to_graph(rows, schema_map))` on
#'   success, otherwise `list(ok = FALSE, reason = <character>)`.
#' @keywords internal
try_rows_to_graph <- function(rows, schema_map) {
  if (!is.list(rows) || length(rows) == 0L) {
    return(list(ok = FALSE, reason = "Query liefert keine Zeilen."))
  }
  res <- tryCatch(rows_to_graph(rows, schema_map), error = function(e) e)
  if (inherits(res, "error")) {
    return(list(ok = FALSE, reason = conditionMessage(res)))
  }
  list(ok = TRUE, model = res)
}

#' Cap a graph model to its first `n` nodes in the model's node order.
#'
#' Keeps the first `n` rows of `model$nodes` (the caller is responsible for
#' putting them in display order, e.g. BFS distance from a focus center) plus
#' only the edges whose two endpoints are both kept, so the result is a valid
#' drop-in model for `renderG6` (which reads `$nodes` and `$edges`). The
#' `table` is passed through untouched -- the view renders the full filtered
#' table, not the capped one.
#'
#' @param model A model with `$nodes` (id,...) and `$edges` (id,source,target)
#'   data.frames, as returned by `rows_to_graph()` / `ego_subgraph()`.
#' @param n Number of nodes to keep. If `n >= nrow(model$nodes)` the model is
#'   returned unchanged.
#' @return `list(nodes =, edges =, table =)` with at most `n` nodes.
#' @keywords internal
cap_graph <- function(model, n) {
  if (is.null(model$nodes) || is.null(model$edges)) {
    rlang::abort("cap_graph() requires a model with $nodes and $edges.")
  }
  n <- max(0L, as.integer(n))
  n_all <- nrow(model$nodes)
  if (n >= n_all) {
    return(model)
  }
  nodes <- model$nodes[seq_len(n), , drop = FALSE]
  ids <- nodes$id
  edges <- model$edges[
    model$edges$source %in% ids & model$edges$target %in% ids,
    , drop = FALSE
  ]
  list(nodes = nodes, edges = edges, table = model$table)
}
