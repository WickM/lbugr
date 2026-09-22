#' Tests for ego_subgraph (R/graph_viewer_context.R).
#' Ported from the metadata-mesh-viewer (test-neighborhood.R), box::use removed.

# Undirected chain p1 - g1 - p2 - g2, plus isolated p3.
viewer_neighborhood_graph <- function() {
  rows <- list(
    list(type = "prozess", id = "p1", label = "P1"),
    list(type = "prozess", id = "p2", label = "P2"),
    list(type = "prozess", id = "p3", label = "P3"),
    list(type = "geschaeftsbegriff", id = "g1", label = "G1"),
    list(type = "geschaeftsbegriff", id = "g2", label = "G2"),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL, source = "p1", target = "g1"),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL, source = "p2", target = "g1"),
    list(type = "prozesse_terme_rel", id = NULL, label = NULL, source = "p2", target = "g2")
  )
  rows_to_graph(rows, parse_schema(viewer_test_schema()))
}

test_that("1-hop ego returns the center and its direct neighbors", {
  out <- ego_subgraph("prozess:p1", viewer_neighborhood_graph(), hops = 1L)
  expect_identical(sort(out$nodes$id), c("geschaeftsbegriff:g1", "prozess:p1"))
  expect_identical(nrow(out$edges), 1L)
})

test_that("2-hop ego walks one more level along the chain", {
  out <- ego_subgraph("prozess:p1", viewer_neighborhood_graph(), hops = 2L)
  expect_identical(
    sort(out$nodes$id),
    c("geschaeftsbegriff:g1", "prozess:p1", "prozess:p2")
  )
  expect_identical(nrow(out$edges), 2L) # p1-g1, p2-g1 (p2-g2 excluded: g2 not reached)
})

test_that("3-hop ego reaches the end of the chain", {
  out <- ego_subgraph("prozess:p1", viewer_neighborhood_graph(), hops = 3L)
  expect_identical(
    sort(out$nodes$id),
    c("geschaeftsbegriff:g1", "geschaeftsbegriff:g2", "prozess:p1", "prozess:p2")
  )
  expect_identical(nrow(out$edges), 3L) # p1-g1, p2-g1, p2-g2
})

test_that("a hub center pulls in all of its direct edges", {
  out <- ego_subgraph("prozess:p2", viewer_neighborhood_graph(), hops = 1L)
  expect_identical(
    sort(out$nodes$id),
    c("geschaeftsbegriff:g1", "geschaeftsbegriff:g2", "prozess:p2")
  )
  expect_identical(nrow(out$edges), 2L) # p2-g1, p2-g2
})

test_that("an isolated node yields a single-node, zero-edge ego", {
  out <- ego_subgraph("prozess:p3", viewer_neighborhood_graph(), hops = 2L)
  expect_identical(out$nodes$id, "prozess:p3")
  expect_identical(nrow(out$edges), 0L)
})

test_that("the ego keeps the model shape and only references kept nodes", {
  out <- ego_subgraph("prozess:p1", viewer_neighborhood_graph(), hops = 3L)
  expect_identical(colnames(out$nodes), c("id", "label", "type", "color"))
  expect_identical(colnames(out$edges), c("id", "source", "target", "rel_type"))
  expect_true(all(out$edges$source %in% out$nodes$id))
  expect_true(all(out$edges$target %in% out$nodes$id))
})

test_that("an unknown node id aborts", {
  expect_error(ego_subgraph("prozess:nope", viewer_neighborhood_graph(), hops = 1L),
               regexp = "Unknown node id")
})

test_that("hops below 1 aborts", {
  expect_error(ego_subgraph("prozess:p1", viewer_neighborhood_graph(), hops = 0L),
               regexp = "hops >= 1")
})

test_that("is deterministic across calls", {
  g <- viewer_neighborhood_graph()
  expect_identical(ego_subgraph("prozess:p1", g, hops = 2L),
                   ego_subgraph("prozess:p1", g, hops = 2L))
})

test_that("nodes come back in BFS distance order (center first)", {
  g <- viewer_neighborhood_graph()
  # Chain p1 - g1 - p2 - g2 plus isolated p3. From prozess:p1 the BFS
  # visitation order is p1 (lvl 0) -> g1 (lvl 1) -> p2 (lvl 2) -> g2 (lvl 3).
  out3 <- ego_subgraph("prozess:p1", g, hops = 3L)
  expect_identical(
    out3$nodes$id,
    c("prozess:p1", "geschaeftsbegriff:g1", "prozess:p2", "geschaeftsbegriff:g2")
  )
  # At hops = 2 the third level (g2) is not reached yet.
  out2 <- ego_subgraph("prozess:p1", g, hops = 2L)
  expect_identical(
    out2$nodes$id,
    c("prozess:p1", "geschaeftsbegriff:g1", "prozess:p2")
  )
})
