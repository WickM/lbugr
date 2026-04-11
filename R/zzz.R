# Package Initialization for lbugr

lbugr <- NULL

.onLoad <- function(libname, pkgname) {
  # Use a delayed binding to avoid loading Python until it's needed
  lbugr <<- reticulate::import("real_ladybug", delay_load = TRUE)
}

.onAttach <- function(libname, pkgname) {
  # Check for real_ladybug and provide a helpful message if it's not found
  if (interactive()) {
    if (!reticulate::py_module_available("real_ladybug")) {
      msg <- paste(
        "The 'real_ladybug' Python package is not installed.",
        "\nPlease install it using: reticulate::py_install('real_ladybug', pip = TRUE)"
      )
      packageStartupMessage(msg)
    }
  }
}