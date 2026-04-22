# Installation Check for lbugr

#' Check for Ladybug Python Dependencies
#'
#' This function checks if the required Python package (`ladybug` or `real_ladybug`)
#' is available in the user's `reticulate` environment. The package may be
#' installed under either name - `ladybug` (preferred) or `real_ladybug`
#' (legacy). If the package is missing, it provides a clear, actionable message
#' guiding the user on how to install it manually.
#'
#' @param quiet If TRUE, suppress the success message. Default is FALSE.
#' @return `NULL` invisibly. The function is called for its side effect of
#'   checking dependencies and printing messages.
#' @export
#' @examples
#' \donttest{
#' check_ladybug_installation()
#' }
check_ladybug_installation <- function(quiet = FALSE) {
  ladybug_available <- reticulate::py_module_available("ladybug")
  real_ladybug_available <- reticulate::py_module_available("real_ladybug")

  if (!ladybug_available && !real_ladybug_available) {
    stop(
      "The 'ladybug' Python package is not installed.",
      "\nTo install it, please run the following command in your R console:",
      "\nreticulate::py_install('ladybug', pip = TRUE)",
      call. = FALSE
    )
  }

  pkgs <- c(
    if (ladybug_available) "ladybug",
    if (real_ladybug_available) "real_ladybug"
  )
  pkg_msg <- paste(pkgs, collapse = " and ")

  if (!quiet) {
    message("The '", pkg_msg, "' Python package(s) are installed and available.")
  }
  invisible(NULL)
}