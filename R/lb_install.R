# Installation Check for lbugr

#' Check for Ladybug Dependencies
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. As of version 0.2.0, `lbugr` bundles the
#' Ladybug database engine via Rust, so there are no external dependencies
#' to check. This function is kept for backward compatibility and will be
#' removed in a future version.
#'
#' @param quiet If TRUE, suppress the success message. Default is FALSE.
#' @return `NULL` invisibly. The function is called for its side effect of
#'   printing messages.
#' @export
#' @examples
#' \dontrun{
#' check_ladybug_installation()
#' }
check_ladybug_installation <- function(quiet = FALSE) {
  .Deprecated(
    msg = paste0(
      "check_ladybug_installation() is deprecated as of lbugr 0.2.0.\n",
      "The Ladybug database engine is now bundled via Rust and requires no ",
      "external dependencies.\n",
      "This function will be removed in a future version."
    )
  )
  
  if (!quiet) {
    message(
      "The 'lbugr' package is ready. The Ladybug database engine is bundled ",
      "and no external dependencies are required."
    )
  }
  invisible(NULL)
}
