#' Tests for the pure export serializers (R/graph_viewer_exports.R).
#' Ported from the metadata-mesh-viewer (test-exports.R), box::use removed.

test_that("table_to_csv writes header + rows with escaping", {
  # write.csv(quote = TRUE, the default) quotes all character columns.
  df <- data.frame(a = 1:3, b = c("x,y", "z\"w", "plain"), stringsAsFactors = FALSE)
  expect_equal(
    table_to_csv(df),
    c("\"a\",\"b\"", "1,\"x,y\"", "2,\"z\"\"w\"", "3,\"plain\"")
  )
})

test_that("table_to_csv on an empty frame returns the header only", {
  expect_equal(table_to_csv(data.frame(x = character())), "\"x\"")
})

test_that("rows_to_json round-trips arbitrary rows", {
  rows <- list(list(total = 5L), list(total = 6L, extra = "a"))
  out <- rows_to_json(rows)
  expect_equal(jsonlite::fromJSON(out, simplifyVector = FALSE), rows)
})

test_that("rows_to_json on empty input is an empty JSON array", {
  expect_equal(rows_to_json(list()), "[]")
})

test_that("df_to_xlsx writes a file that reads back identically", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  df <- data.frame(a = 1:2, b = c("x", "y"), stringsAsFactors = FALSE)
  df_to_xlsx(df, tmp)
  expect_true(file.info(tmp)$size > 1000)
  expect_equal(openxlsx::read.xlsx(tmp), df)
})

test_that("serializers reject non-data.frame / non-list input", {
  expect_error(table_to_csv("nope"))
  expect_error(rows_to_json("nope"))
  expect_error(df_to_xlsx("nope", tempfile()))
})
