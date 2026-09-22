# Graph viewer: selection context + ego subgraph (ported from the
# metadata-mesh-viewer: app/logic/context.R + app/logic/neighborhood.R).
#
# Pure functions (no HTTP, no Shiny) — testable without the app.

#' Context (1-hop neighborhood) for a selected node of the graph model.
#'
#' Given a selected node id, classifies every node as "selected" /
#' "neighbor" / "other" and marks the edges that must be dimmed (edges not
#' touching the selected node). The UI uses this for context mode: selected
#' + neighbors stay colored, everything else is greyed out.
#'
#' @param node_id Global node id `<type>:<pk>` (as produced by
#'   `rows_to_graph()`) or `NULL` for no selection.
#' @param graph_model Output of `rows_to_graph()`.
#' @return `list(selected = <node_id or NULL>,
#'   neighbor_ids = <chr vector of 1-hop neighbors>,
#'   node_class = <named chr vector over all node ids>,
#'   dim_edge_ids = <chr vector of edge ids to dim>)`.
#' @keywords internal
context_state <- function(node_id, graph_model) {
  if (!is.null(node_id) &&
      (!is.character(node_id) || length(node_id) != 1L || !nzchar(node_id))
  ) {
    rlang::abort("node_id must be a non-empty single string or NULL.")
  }

  node_ids <- graph_model$nodes$id
  if (!is.null(node_id) && !node_id %in% node_ids) {
    rlang::abort(sprintf("Unknown node id in context_state(): '%s'.", node_id))
  }

  if (is.null(node_id)) {
    node_class <- stats::setNames(rep("none", length(node_ids)), node_ids)
    return(list(
      selected = NULL,
      neighbor_ids = character(0),
      node_class = node_class,
      dim_edge_ids = character(0)
    ))
  }

  edges <- graph_model$edges
  touching <- which(edges$source == node_id | edges$target == node_id)
  neighbor_ids <- unique(c(
    edges$source[touching][edges$source[touching] != node_id],
    edges$target[touching][edges$target[touching] != node_id]
  ))
  node_class <- ifelse(
    node_ids == node_id, "selected",
    ifelse(node_ids %in% neighbor_ids, "neighbor", "other")
  )
  names(node_class) <- node_ids

  # Note: `edges$id[-touching]` would drop ALL edges when `touching` is
  # empty (-integer(0) loses its sign in R), so use a logical mask.
  dim_edge_ids <- edges$id[!seq_len(nrow(edges)) %in% touching]

  list(
    selected = node_id,
    neighbor_ids = neighbor_ids,
    node_class = node_class,
    dim_edge_ids = dim_edge_ids
  )
}

#' Extract the N-hop ego subgraph around a node.
#'
#' Undirected breadth-first search over `graph_model$edges`, starting at
#' `node_id` and expanding up to `hops` levels. Returns a model-shaped list
#' (`nodes`/`edges`/`table`) containing only the reachable nodes and the
#' edges whose endpoints are all inside the neighborhood, so the result is a
#' drop-in model for `renderG6` (which reads `$nodes` and `$edges`).
#'
#' The input `graph_model` is the full filtered model (the module's
#' `visible_model()`), so the ego respects the active node/rel type filters.
#'
#' @param node_id A global node id (`"<type>:<pk>"`) present in the model.
#' @param graph_model A model with `$nodes` (id,label,type,color) and `$edges`
#'   (id,source,target,rel_type) data.frames, as returned by `rows_to_graph()`.
#' @param hops Number of hops (>= 1). Default 2.
#' @return `list(nodes=, edges=, table=)` shaped like `rows_to_graph()`.
#' @keywords internal
ego_subgraph <- function(node_id, graph_model, hops = 2L) {
  if (!is.character(node_id) || length(node_id) != 1L || is.na(node_id) ||
      node_id == ""
  ) {
    rlang::abort("ego_subgraph() requires a non-empty node_id (string).")
  }
  if (!is.numeric(hops) || length(hops) != 1L || is.na(hops) || hops < 1) {
    rlang::abort("ego_subgraph() requires hops >= 1.")
  }
  hops <- as.integer(hops)
  if (is.null(graph_model$nodes) || is.null(graph_model$edges)) {
    rlang::abort("ego_subgraph() requires a graph_model with $nodes and $edges.")
  }
  if (!node_id %in% graph_model$nodes$id) {
    rlang::abort("Unknown node id in ego_subgraph(): ", node_id)
  }

  ids <- graph_model$nodes$id
  src <- graph_model$edges$source
  tgt <- graph_model$edges$target

  visited <- rep(FALSE, length(ids))
  names(visited) <- ids
  visited[node_id] <- TRUE
  # BFS order: the center first, then each reached level in visitation order.
  # The focus view caps by this order (closest first), so the selected center
  # is always row 1 and can never be hidden by the cap.
  keep <- node_id
  frontier <- node_id

  for (h in seq_len(hops)) {
    nbrs <- unique(c(tgt[src %in% frontier], src[tgt %in% frontier]))
    nbrs <- nbrs[!visited[nbrs]]
    if (length(nbrs) == 0L) break
    visited[nbrs] <- TRUE
    frontier <- nbrs
    keep <- c(keep, nbrs)
  }

  # Reorder the model rows into `keep` (BFS) order, not the model's row order.
  nodes <- graph_model$nodes[match(keep, ids), , drop = FALSE]
  edges <- graph_model$edges[
    graph_model$edges$source %in% keep &
      graph_model$edges$target %in% keep,
    , drop = FALSE
  ]
  table_rows <- NULL
  if (!is.null(graph_model$table)) {
    table_rows <- graph_model$table[
      graph_model$table$kind == "node" & graph_model$table$id %in% keep,
      , drop = FALSE
    ]
  }

  list(nodes = nodes, edges = edges, table = table_rows)
}
