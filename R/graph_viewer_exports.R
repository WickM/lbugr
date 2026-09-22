# Graph viewer: pure serializers for exports (ported from the
# metadata-mesh-viewer: app/logic/exports.R).
#
# No Shiny, no HTTP. The view layer's `downloadHandler`s call these.
# (PNG is a client-side canvas download -- no R serialization involved.)

#' CSV text for a table data frame.
#'
#' @param df Data frame (table view).
#' @return Character vector of CSV lines (header + data rows, no trailing
#'   newline).
#' @keywords internal
table_to_csv <- function(df) {
  if (!is.data.frame(df)) {
    rlang::abort("df must be a data.frame.")
  }
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(df, tmp, row.names = FALSE)
  readLines(tmp, warn = FALSE)
}

#' JSON text for raw result rows.
#'
#' @param rows List of row lists (`viewer_run_query()$results`).
#' @return Single JSON string (JSON array of objects).
#' @keywords internal
rows_to_json <- function(rows) {
  if (!is.list(rows)) {
    rlang::abort("rows must be a list of row lists (viewer_run_query()$results).")
  }
  as.character(jsonlite::toJSON(rows, auto_unbox = TRUE, digits = NA))
}

#' Write a table data frame to an xlsx file.
#'
#' @param df Data frame (table view).
#' @param path Target file path.
#' @return `path` (invisible).
#' @keywords internal
df_to_xlsx <- function(df, path) {
  if (!is.data.frame(df)) {
    rlang::abort("df must be a data.frame.")
  }
  openxlsx::write.xlsx(df, file = path, rowNames = FALSE)
  invisible(path)
}
