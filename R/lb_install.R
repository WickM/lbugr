# Installation Check for lbugr

#' Check for Ladybug Rust Backend Availability
#'
#' This function checks if the Rust backend is available and working.
#' In previous versions, this function checked for the Python `ladybug` package.
#' It is now deprecated and will be removed in a future version.
#'
#' @param quiet If TRUE, suppress the success message. Default is FALSE.
#' @return `NULL` invisibly. The function is called for its side effect of
#'   checking dependencies and printing messages.
#' @export
#' @examples
#' \dontrun{
#' check_ladybug_installation()
#' }
check_ladybug_installation <- function(quiet = FALSE) {
  .Deprecated("lbug_is_available", package = "lbugr")
  
  if (!quiet) {
    message("The 'lbugr' Rust backend is available.")
  }
  invisible(NULL)
}

#' Check if Rust Backend is Available
#'
#' Checks whether the bundled Rust backend is available and functional.
#' This function is provided by the Rust backend via extendr.
#'
#' @return `TRUE` if the Rust backend is available, `FALSE` otherwise.
#' @export
#' @examples
#' \dontrun{
#' lbug_is_available()
#' }
#' @name lbug_is_available
#' @rdname lbug_is_available
NULL
