#' DB tests for the local graph viewer: schema fetch (DC1), full round-trip
#' (DC2), blocklist (DC4), and the OPTIONAL MATCH regression (plan D9).

skip_if_no_ladybug()

viewer_db_seed <- function(conn) {
  lb_execute(conn, "CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE NODE TABLE City(name STRING, population INT64, PRIMARY KEY (name))")
  lb_execute(conn, "CREATE REL TABLE Knows(FROM Person TO Person)")
  lb_execute(conn, "CREATE REL TABLE LivesIn(FROM Person TO City)")
  lb_execute(conn, "CREATE (:Person {name: 'Alice', age: 30}), (:Person {name: 'Bob', age: 25}), (:City {name: 'Berlin', population: 3600000}), (:City {name: 'Munich', population: 1500000})")
  lb_execute(conn, "MATCH (a:Person), (b:Person) WHERE a.name = 'Alice' AND b.name = 'Bob' CREATE (a)-[:Knows]->(b)")
  lb_execute(conn, "MATCH (p:Person), (c:City) WHERE p.name = 'Alice' AND c.name = 'Berlin' CREATE (p)-[:LivesIn]->(c)")
  conn
}

test_that("viewer_fetch_schema returns the /schema shape (DC1)", {
  conn <- viewer_db_seed(test_conn(environment()))
  schema <- viewer_fetch_schema(conn)

  expect_setequal(
    vapply(schema$node_tables, `[[`, character(1), "name"),
    c("Person", "City")
  )
  person <- schema$node_tables[[which(vapply(schema$node_tables, `[[`, character(1), "name") == "Person")]]
  expect_identical(as.integer(person$count), 2L)
  expect_setequal(vapply(person$columns, `[[`, character(1), "name"), c("name", "age"))
  name_col <- person$columns[[which(vapply(person$columns, `[[`, character(1), "name") == "name")]]
  age_col <- person$columns[[which(vapply(person$columns, `[[`, character(1), "name") == "age")]]
  expect_identical(name_col$type, "STRING")
  expect_identical(age_col$type, "INT64")
  expect_true(isTRUE(name_col[["primary key"]]))
  expect_false(isTRUE(age_col[["primary key"]]))

  expect_setequal(
    vapply(schema$rel_tables, `[[`, character(1), "name"),
    c("Knows", "LivesIn")
  )
  knows <- schema$rel_tables[[which(vapply(schema$rel_tables, `[[`, character(1), "name") == "Knows")]]
  expect_identical(as.integer(knows$count), 1L)
  conn1 <- knows$connection[[1]]
  expect_identical(conn1$from, "Person")
  expect_identical(conn1$to, "Person")
  expect_identical(conn1$from_pk, "name")
  expect_identical(conn1$to_pk, "name")
  lives_in <- schema$rel_tables[[which(vapply(schema$rel_tables, `[[`, character(1), "name") == "LivesIn")]]
  expect_identical(lives_in$connection[[1]]$from, "Person")
  expect_identical(lives_in$connection[[1]]$to, "City")
})

test_that("full round-trip: fetch -> parse -> generate -> run -> graph (DC2)", {
  conn <- viewer_db_seed(test_conn(environment()))
  schema <- viewer_fetch_schema(conn)
  map <- parse_schema(schema)
  query <- generate_graph_query(map)
  res <- viewer_run_query(conn, query)

  expect_identical(res$row_count, 6L) # 4 node rows + 2 edge rows
  g <- rows_to_graph(res$results, map)
  expect_identical(
    sort(g$nodes$id),
    c("City:Berlin", "City:Munich", "Person:Alice", "Person:Bob")
  )
  expect_identical(sort(g$nodes$label), c("Alice", "Berlin", "Bob", "Munich"))
  expect_identical(nrow(g$edges), 2L)
  expect_setequal(g$edges$rel_type, c("Knows", "LivesIn"))
  expect_true(all(g$edges$source %in% g$nodes$id))
  expect_true(all(g$edges$target %in% g$nodes$id))
})

test_that("viewer_run_query returns uniform row lists + row count", {
  conn <- viewer_db_seed(test_conn(environment()))
  res <- viewer_run_query(conn, "MATCH (n:Person) RETURN n.name AS name, n.age AS age")
  expect_identical(res$row_count, 2L)
  expect_length(res$results, 2L)
  expect_named(res$results[[1L]], c("name", "age"))
  expect_true(all(vapply(res$results, is.list, logical(1))))
})

test_that("write keywords are blocked before execution (DC4)", {
  conn <- viewer_db_seed(test_conn(environment()))
  for (q in c(
    "CREATE NODE TABLE Hacked(x STRING, PRIMARY KEY (x))",
    "DROP NODE TABLE Person",
    "MATCH (n:Person) DELETE n",
    "MATCH (a:Person), (b:Person) MERGE (a)-[:Knows]->(b)",
    "ALTER NODE TABLE Person ADD z INT64"
  )) {
    expect_error(viewer_run_query(conn, q), regexp = "blocked keyword", info = q)
  }
  # Nothing was created/executed.
  expect_setequal(
    vapply(viewer_fetch_schema(conn)$node_tables, `[[`, character(1), "name"),
    c("Person", "City")
  )
})

test_that("word-boundary matching: property names like created_at are not blocked", {
  expect_no_error(viewer_check_query("MATCH (n:Person) WHERE n.created_at = 1 RETURN n"))
  expect_no_error(viewer_check_query("MATCH (n) WHERE n.deleted = false RETURN n"))
  expect_no_error(viewer_check_query("MATCH (n:Person) RETURN n.name, n.age"))
})

test_that("viewer_check_query rejects empty/non-string input", {
  expect_error(viewer_check_query(""), regexp = "non-empty")
  expect_error(viewer_check_query(42), regexp = "non-empty")
})

test_that("OPTIONAL MATCH with mixed rows returns a column-union df (D9)", {
  conn <- viewer_db_seed(test_conn(environment()))
  df <- lb_execute(conn, "MATCH (n) OPTIONAL MATCH (n)-[r]->(m) RETURN n, r, m")
  # 2 rows with a relationship (Alice) + 3 isolated nodes (Bob, Berlin, Munich)
  expect_identical(nrow(df), 5L)
  expect_true("n._LABEL" %in% names(df))
  expect_true("r._LABEL" %in% names(df))
  expect_true("m._LABEL" %in% names(df))
  # Rows without a relationship carry NA in the relationship columns.
  no_rel <- df[is.na(df[["r._LABEL"]]), ]
  expect_identical(nrow(no_rel), 3L)
})
