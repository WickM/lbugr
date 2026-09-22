#' Tests for rows_to_graph (R/graph_viewer_model.R).
#' Ported from the metadata-mesh-viewer (test-graph_model.R), box::use removed.

fixture_rows <- function() {
  list(
    list(type = "prozess", id = "p1", label = "Prozess 1", source = NULL, target = NULL),
    list(type = "geschaeftsbegriff", id = "t1", label = "Begriff 1", source = NULL, target = NULL),
    list(type = "prozess", id = "p2", label = NULL, source = NULL, target = NULL),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL,
         source = "p1", target = "t1"),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL,
         source = "p1", target = "t1")
  )
}

fixture_map <- function() {
  parse_schema(viewer_test_schema())
}

test_that("builds prefixed node ids, label fallback and distinct type colors", {
  g <- rows_to_graph(fixture_rows(), fixture_map())
  expect_identical(g$nodes$id, c("geschaeftsbegriff:t1", "prozess:p1", "prozess:p2"))
  expect_identical(g$nodes$label, c("Begriff 1", "Prozess 1", "p2"))
  expect_identical(g$nodes$type, c("geschaeftsbegriff", "prozess", "prozess"))
  expect_identical(
    g$nodes$color[g$nodes$type == "prozess"],
    rep(g$nodes$color[g$nodes$type == "prozess"][[1]], 2L)
  )
  expect_true(g$nodes$color[g$nodes$type == "prozess"][[1]] !=
                g$nodes$color[g$nodes$type == "geschaeftsbegriff"][[1]])
})

test_that("resolves edge endpoints via the schema map and dedupes edge ids", {
  g <- rows_to_graph(fixture_rows(), fixture_map())
  expect_identical(g$edges$source, c("prozess:p1", "prozess:p1"))
  expect_identical(g$edges$target, c("geschaeftsbegriff:t1", "geschaeftsbegriff:t1"))
  expect_identical(g$edges$rel_type, c("prozesse_terme_rel", "prozesse_terme_rel"))
  expect_identical(
    g$edges$id,
    c(
      "prozess:p1|prozesse_terme_rel|geschaeftsbegriff:t1",
      "prozess:p1|prozesse_terme_rel|geschaeftsbegriff:t1:2"
    )
  )
})

test_that("table has one row per input row, in deterministic order", {
  g <- rows_to_graph(fixture_rows(), fixture_map())
  expect_identical(g$table$kind, c("node", "node", "node", "edge", "edge"))
  expect_identical(g$table$type, c(
    "geschaeftsbegriff", "prozess", "prozess",
    "prozesse_terme_rel", "prozesse_terme_rel"
  ))
  expect_identical(g$table$id, c(
    "geschaeftsbegriff:t1", "prozess:p1", "prozess:p2",
    "prozess:p1|prozesse_terme_rel|geschaeftsbegriff:t1",
    "prozess:p1|prozesse_terme_rel|geschaeftsbegriff:t1:2"
  ))
  expect_identical(g$table$label, c("Begriff 1", "Prozess 1", "p2", "", ""))
  expect_identical(g$table$source, c("", "", "", "prozess:p1", "prozess:p1"))
  expect_identical(
    g$table$target, c("", "", "", "geschaeftsbegriff:t1", "geschaeftsbegriff:t1")
  )
})

test_that("empty rows yield empty data frames with the documented columns", {
  g <- rows_to_graph(list(), fixture_map())
  expect_identical(colnames(g$nodes), c("id", "label", "type", "color"))
  expect_identical(colnames(g$edges), c("id", "source", "target", "rel_type"))
  expect_identical(
    colnames(g$table), c("kind", "type", "id", "label", "source", "target")
  )
  expect_identical(nrow(g$nodes), 0L)
  expect_identical(nrow(g$edges), 0L)
  expect_identical(nrow(g$table), 0L)
})

test_that("is deterministic across calls", {
  g1 <- rows_to_graph(fixture_rows(), fixture_map())
  g2 <- rows_to_graph(fixture_rows(), fixture_map())
  expect_identical(g1, g2)
})

test_that("rejects rows that are neither node nor edge rows", {
  rows <- list(list(type = "prozess", id = NULL, label = NULL,
                    source = NULL, target = NULL))
  expect_error(rows_to_graph(rows, fixture_map()),
               regexp = "node row \\(id\\) or an edge row")
})

test_that("rejects rows that are both node and edge rows", {
  rows <- list(list(type = "prozess", id = "p1", label = "P",
                    source = "x", target = "y"))
  expect_error(rows_to_graph(rows, fixture_map()), regexp = "both a node row")
})

test_that("rejects unknown rel types", {
  rows <- list(list(type = "kein_rel", id = NULL, label = NULL,
                    source = "p1", target = "t1"))
  expect_error(rows_to_graph(rows, fixture_map()), regexp = "Unknown rel type")
})
test_that("rows_to_df unions fields across rows in first-seen order", {
  rows <- list(list(total = 5L), list(name = "x", total = 6L))
  df <- rows_to_df(rows)
  expect_equal(names(df), c("total", "name"))
  expect_equal(nrow(df), 2L)
  expect_true(is.na(df$name[1]))
  expect_equal(df$total, c(5L, 6L))
})

test_that("rows_to_df on empty rows returns a 0-row data.frame", {
  expect_equal(nrow(rows_to_df(list())), 0L)
})

test_that("rows_to_df rejects non-list input", {
  expect_error(rows_to_df("nope"), regexp = "list of row lists")
})

test_that("try_rows_to_graph classifies graph-capable vs. non-graph results", {
  ok <- try_rows_to_graph(fixture_rows(), fixture_map())
  expect_true(ok$ok)
  expect_identical(nrow(ok$model$nodes), 3L)
  expect_identical(nrow(ok$model$edges), 2L)

  # A scalar / count row is not a graph (rows_to_graph aborts).
  scalar <- try_rows_to_graph(list(list(total = 42L)), fixture_map())
  expect_false(scalar$ok)
  expect_true(is.character(scalar$reason))

  # An unknown rel type is not a graph.
  bad_rel <- try_rows_to_graph(
    list(list(type = "kein_rel", id = NULL, label = NULL,
              source = "p1", target = "t1")),
    fixture_map()
  )
  expect_false(bad_rel$ok)

  # Empty results are not a graph.
  expect_false(try_rows_to_graph(list(), fixture_map())$ok)
})

test_that("a node-only (zero-edge) result is graph-capable (no spurious edge NA)", {
  # Regression: the edge reindex used `paste0(..., "|", ...)` which returns
  # length 1 even when the indexed columns are empty, so `integer(0)[1]` -> NA
  # -> "Unknown rel type NA". Node-only free queries must stay graph-capable.
  node_only <- list(
    list(type = "prozess", id = "p1", label = "P"),
    list(type = "prozess", id = "p2", label = "Q")
  )
  out <- try_rows_to_graph(node_only, fixture_map())
  expect_true(out$ok)
  expect_identical(nrow(out$model$nodes), 2L)
  expect_identical(nrow(out$model$edges), 0L)

  # rows_to_graph itself must not abort on the zero-edge path.
  g <- rows_to_graph(node_only, fixture_map())
  expect_identical(nrow(g$nodes), 2L)
  expect_identical(nrow(g$edges), 0L)
  expect_identical(g$table$kind, c("node", "node"))
})

test_that("cap_graph keeps the first n nodes in order + only internal edges", {
  model <- list(
    nodes = data.frame(
      id = c("n1", "n2", "n3", "n4"),
      label = c("N1", "N2", "N3", "N4"),
      type = "t",
      color = c("red", "blue", "green", "yellow"),
      stringsAsFactors = FALSE
    ),
    edges = data.frame(
      id = c("e1", "e2", "e3"),
      source = c("n1", "n2", "n3"),
      target = c("n2", "n3", "n4"),
      rel_type = "r",
      stringsAsFactors = FALSE
    ),
    table = data.frame(
      kind = "node", type = "t", id = c("n1", "n2", "n3", "n4"),
      label = c("N1", "N2", "N3", "N4"),
      source = NA, target = NA, stringsAsFactors = FALSE
    )
  )
  # n >= n_all: returned unchanged.
  expect_identical(cap_graph(model, 4L), model)
  # n = 2: first two nodes in the model's row order, only the internal edge.
  c2 <- cap_graph(model, 2L)
  expect_identical(c2$nodes$id, c("n1", "n2"))
  expect_identical(c2$edges$id, "e1")
  # n = 1: single node, no internal edges.
  c1 <- cap_graph(model, 1L)
  expect_identical(c1$nodes$id, "n1")
  expect_identical(nrow(c1$edges), 0L)
  # n = 0: empty model.
  c0 <- cap_graph(model, 0L)
  expect_identical(nrow(c0$nodes), 0L)
  expect_identical(nrow(c0$edges), 0L)
})

test_that("cap_graph requires a model with $nodes and $edges", {
  expect_error(cap_graph(list(), 2L), regexp = "requires a model")
})
