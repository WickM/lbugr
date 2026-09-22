#' Golden tests for generate_graph_query (R/graph_viewer_query.R).
#' Ported from the metadata-mesh-viewer (test-cypher_gen.R), box::use removed.
#' Deviation D10: identifiers may be CamelCase (local DBs), so the regex is
#' relaxed from [a-z] to [A-Za-z] (injection still impossible).

expected_query <- paste0(
  "MATCH (n:prozess)\n",
  "RETURN 'prozess' AS type, n.prozess_id AS id, ",
  "coalesce(n.bezeichnung_prozess, n.prozess_id) AS label, ",
  "CAST(NULL AS STRING) AS source, CAST(NULL AS STRING) AS target\n",
  "UNION\n",
  "MATCH (n:geschaeftsbegriff)\n",
  "RETURN 'geschaeftsbegriff' AS type, n.geschaeftsbegriff_id AS id, ",
  "coalesce(n.bezeichnung_geschaeftsbegriff, n.geschaeftsbegriff_id) AS label, ",
  "CAST(NULL AS STRING) AS source, CAST(NULL AS STRING) AS target\n",
  "UNION\n",
  "MATCH (a:prozess)-[r:prozesse_terme_rel]->(b:geschaeftsbegriff)\n",
  "RETURN 'prozesse_terme_rel' AS type, CAST(NULL AS STRING) AS id, ",
  "CAST(NULL AS STRING) AS label, a.prozess_id AS source, ",
  "b.geschaeftsbegriff_id AS target"
)

test_that("generates the exact golden query for the fixture schema", {
  expect_identical(
    generate_graph_query(parse_schema(viewer_test_schema())),
    expected_query
  )
})

test_that("is deterministic across calls", {
  map <- parse_schema(viewer_test_schema())
  expect_identical(generate_graph_query(map), generate_graph_query(map))
})

test_that("uses coalesce(label, bezeichnung_*, pk) when a label column exists", {
  schema <- viewer_test_schema()
  schema$node_tables[[1]]$columns <- list(
    list(name = "label", type = "STRING", `primary key` = FALSE),
    list(name = "bezeichnung_prozess", type = "STRING", `primary key` = FALSE),
    list(name = "prozess_id", type = "STRING", `primary key` = TRUE)
  )
  q <- generate_graph_query(parse_schema(schema))
  expect_match(q, "coalesce\\(n.label, n.bezeichnung_prozess, n.prozess_id\\) AS label")
})

test_that("accepts CamelCase identifiers (local DBs, deviation D10)", {
  map <- list(
    nodes = list(
      Person = list(
        name = "Person", pk = "name", label_cols = c("name"),
        columns = NULL, count = 1L
      )
    ),
    rels = list()
  )
  q <- generate_graph_query(map)
  expect_match(q, "MATCH \\(n:Person\\)")
})

test_that("rejects invalid Cypher identifiers", {
  bad_map <- list(
    nodes = list(
      `my-table` = list(
        name = "my-table", pk = "x_id", label_cols = c("bezeichnung_x"),
        columns = NULL, count = 0L
      )
    ),
    rels = list()
  )
  expect_error(generate_graph_query(bad_map), regexp = "Invalid Cypher identifier")
})

test_that("rejects an empty schema map", {
  expect_error(
    generate_graph_query(list(nodes = list(), rels = list())),
    regexp = "empty schema map"
  )
})

test_that("live 7-node/11-rel snapshot yields 18 UNION branches in schema order", {
  live <- jsonlite::fromJSON(
    test_path("fixtures", "schema_live.json"),
    simplifyVector = FALSE
  )
  q <- generate_graph_query(parse_schema(live))
  branches <- strsplit(q, "\nUNION\n", fixed = TRUE)[[1]]
  expect_identical(length(branches), 18L)
  expect_match(q, "^MATCH \\(n:datenart\\)\\nRETURN")
})
