# Installation Check for lbugr

#' Check for Ladybug Python Dependencies
#'
#' This function checks if the required Python package (`ladybug`)
#' is available in the user's `reticulate` environment. If the package is missing,
#' it provides a clear, actionable message guiding the user on how to install it manually.
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
  ladybug_available <- reticulate::py_module_available("ladybug")

  if (!ladybug_available) {
    stop(
      "The 'ladybug' Python package is not installed.",
      "\nTo install it, please run the following command in your R console:",
      "\nreticulate::py_install('ladybug', pip = TRUE)",
      call. = FALSE
    )
  }

  if (!quiet) {
    message("The 'ladybug' Python package is installed and available.")
  }
  invisible(NULL)
}