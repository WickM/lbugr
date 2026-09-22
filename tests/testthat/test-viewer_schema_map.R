#' Tests for parse_schema (R/graph_viewer_schema.R).
#' Ported from the metadata-mesh-viewer (app/logic/schema_map.R), box::use removed.

test_that("parses node tables (pk, label column, columns, count)", {
  schema <- viewer_test_schema()
  map <- parse_schema(schema)
  expect_identical(names(map$nodes), c("prozess", "geschaeftsbegriff"))
  expect_identical(map$nodes$prozess$pk, "prozess_id")
  expect_identical(
    map$nodes$prozess$label_cols,
    c("bezeichnung_prozess", "prozess_id")
  )
  expect_identical(as.integer(map$nodes$prozess$count), 1L)
  expect_identical(
    map$nodes$prozess$columns$name,
    c("bezeichnung_prozess", "prozess_id")
  )
  expect_identical(map$nodes$prozess$columns$primary_key, c(FALSE, TRUE))
})

test_that("parses rel tables (from/to + foreign keys)", {
  map <- parse_schema(viewer_test_schema())
  rel <- map$rels$prozesse_terme_rel
  expect_identical(rel$from, "prozess")
  expect_identical(rel$to, "geschaeftsbegriff")
  expect_identical(rel$from_pk, "prozess_id")
  expect_identical(rel$to_pk, "geschaeftsbegriff_id")
})

test_that("falls back to the primary key when no bezeichnung_ column exists", {
  schema <- viewer_test_schema()
  schema$node_tables[[1]]$columns <- list(
    list(name = "prozess_id", type = "STRING", `primary key` = TRUE)
  )
  map <- parse_schema(schema)
  expect_identical(map$nodes$prozess$label_cols, "prozess_id")
})

test_that("prefers label, then bezeichnung_*, then the primary key", {
  schema <- viewer_test_schema()
  schema$node_tables[[1]]$columns <- list(
    list(name = "label", type = "STRING", `primary key` = FALSE),
    list(name = "bezeichnung_prozess", type = "STRING", `primary key` = FALSE),
    list(name = "prozess_id", type = "STRING", `primary key` = TRUE)
  )
  map <- parse_schema(schema)
  expect_identical(
    map$nodes$prozess$label_cols,
    c("label", "bezeichnung_prozess", "prozess_id")
  )
})

test_that("parses the live 7-node/11-rel schema snapshot", {
  live <- jsonlite::fromJSON(
    test_path("fixtures", "schema_live.json"),
    simplifyVector = FALSE
  )
  map <- parse_schema(live)
  expect_identical(length(map$nodes), 7L)
  expect_identical(length(map$rels), 11L)
  expect_identical(map$nodes$datenart$pk, "datenart_id")
  all_resolved <- vapply(
    map$rels,
    function(rel) !is.null(map$nodes[[rel$from]]) && !is.null(map$nodes[[rel$to]]),
    logical(1)
  )
  expect_true(all(all_resolved))
})

test_that("rejects malformed schema documents", {
  base <- viewer_test_schema()

  bad_no_pk <- base
  bad_no_pk$node_tables[[1]]$columns <- list(
    list(name = "bezeichnung_prozess", type = "STRING", `primary key` = FALSE)
  )
  expect_error(parse_schema(bad_no_pk), regexp = "exactly one primary key")

  bad_two_pk <- base
  bad_two_pk$node_tables[[1]]$columns[[1]]$`primary key` <- TRUE
  expect_error(parse_schema(bad_two_pk), regexp = "exactly one primary key")

  bad_from <- base
  bad_from$rel_tables[[1]]$connection[[1]]$from <- "keine_tabelle"
  expect_error(parse_schema(bad_from), regexp = "unknown from-table")

  bad_no_name <- base
  bad_no_name$node_tables[[2]]$name <- ""
  expect_error(parse_schema(bad_no_name), regexp = "non-empty 'name'")

  bad_no_conn <- base
  bad_no_conn$rel_tables[[1]]$connection <- list()
  expect_error(parse_schema(bad_no_conn), regexp = "non-empty 'connection'")

  expect_error(parse_schema(list()), regexp = "node_tables")
  expect_error(parse_schema("nope"), regexp = "parsed JSON object")
})
