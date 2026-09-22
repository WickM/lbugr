#' Tests for context_state (R/graph_viewer_context.R).
#' Ported from the metadata-mesh-viewer (test-context.R), box::use removed.

#' Small graph: p1 -- t1, p1 -- t2, t1 -- d1. Global ids: prozess:p1 etc.
viewer_context_model <- function() {
  rows <- list(
    list(type = "prozess", id = "p1", label = "P1", source = NULL, target = NULL),
    list(type = "geschaeftsbegriff", id = "t1", label = "T1", source = NULL, target = NULL),
    list(type = "geschaeftsbegriff", id = "t2", label = "T2", source = NULL, target = NULL),
    list(type = "database_column", id = "d1", label = "D1", source = NULL, target = NULL),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL, source = "p1", target = "t1"),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL, source = "p1", target = "t2"),
    list(type = "dq_operativ_term_rel", id = NULL, label = NULL, source = "t1", target = "d1")
  )
  schema_map <- list(
    nodes = list(),
    rels = list(
      prozesse_terme_rel = list(
        name = "prozesse_terme_rel", from = "prozess", to = "geschaeftsbegriff",
        from_pk = "prozess_id", to_pk = "geschaeftsbegriff_id", count = 0L
      ),
      dq_operativ_term_rel = list(
        name = "dq_operativ_term_rel", from = "geschaeftsbegriff", to = "database_column",
        from_pk = "geschaeftsbegriff_id", to_pk = "database_column_id", count = 0L
      )
    )
  )
  rows_to_graph(rows, schema_map)
}

test_that("no selection: all nodes 'none', no dimmed edges", {
  ctx <- context_state(NULL, viewer_context_model())
  expect_true(is.null(ctx$selected))
  expect_identical(ctx$neighbor_ids, character(0))
  expect_identical(ctx$dim_edge_ids, character(0))
  expect_true(all(unname(ctx$node_class) == "none"))
  expect_identical(sort(names(ctx$node_class)),
    sort(c("prozess:p1", "geschaeftsbegriff:t1", "geschaeftsbegriff:t2", "database_column:d1"))
  )
})

test_that("selection: selected/neighbor/other classes + dimmed edges", {
  ctx <- context_state("prozess:p1", viewer_context_model())
  expect_identical(ctx$selected, "prozess:p1")
  expect_identical(sort(ctx$neighbor_ids), c("geschaeftsbegriff:t1", "geschaeftsbegriff:t2"))
  expect_identical(ctx$node_class[["prozess:p1"]], "selected")
  expect_identical(ctx$node_class[["geschaeftsbegriff:t1"]], "neighbor")
  expect_identical(ctx$node_class[["geschaeftsbegriff:t2"]], "neighbor")
  expect_identical(ctx$node_class[["database_column:d1"]], "other")
  # Only the t1-d1 edge does not touch p1.
  expect_length(ctx$dim_edge_ids, 1L)
  expect_match(ctx$dim_edge_ids[[1]], "dq_operativ_term_rel")
})

test_that("isolated node: all edges dimmed, no neighbors", {
  rows <- list(
    list(type = "prozess", id = "p1", label = "P1", source = NULL, target = NULL),
    list(type = "prozess", id = "p2", label = "P2", source = NULL, target = NULL),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL, source = "p2", target = "t1")
  )
  model <- rows_to_graph(rows, list(
    nodes = list(),
    rels = list(prozesse_terme_rel = list(
      name = "prozesse_terme_rel", from = "prozess", to = "geschaeftsbegriff",
      from_pk = "prozess_id", to_pk = "geschaeftsbegriff_id", count = 0L
    ))
  ))
  ctx <- context_state("prozess:p1", model)
  expect_identical(ctx$neighbor_ids, character(0))
  expect_length(ctx$dim_edge_ids, 1L)
  expect_identical(ctx$node_class[["prozess:p2"]], "other")
})

test_that("unknown node id aborts", {
  expect_error(context_state("prozess:zzz", viewer_context_model()), "Unknown node id")
})

test_that("invalid node_id aborts", {
  expect_error(context_state("prozess:p1", viewer_context_model()), NA)
  expect_error(context_state(42, viewer_context_model()), "node_id")
  expect_error(context_state(c("a", "b"), viewer_context_model()), "node_id")
})
