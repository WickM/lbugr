# Shared fixture for the graph-viewer test suite.
# Mirrors the reference app's per-file fixture_schema() (mesh domain:
# lowercase 4-Klang-style table names).

viewer_test_schema <- function() {
  list(
    node_tables = list(
      list(
        name = "prozess",
        count = 1L,
        columns = list(
          list(name = "bezeichnung_prozess", type = "STRING", `primary key` = FALSE),
          list(name = "prozess_id", type = "STRING", `primary key` = TRUE)
        )
      ),
      list(
        name = "geschaeftsbegriff",
        count = 0L,
        columns = list(
          list(name = "bezeichnung_geschaeftsbegriff", type = "STRING", `primary key` = FALSE),
          list(name = "geschaeftsbegriff_id", type = "STRING", `primary key` = TRUE)
        )
      )
    ),
    rel_tables = list(
      list(
        name = "prozesse_terme_rel",
        count = 0L,
        connection = list(
          list(
            from = "prozess", from_pk = "prozess_id",
            to = "geschaeftsbegriff", to_pk = "geschaeftsbegriff_id"
          )
        )
      )
    )
  )
}
