# Package Initialization for lbugr

lbugr <- NULL

.onLoad <- function(libname, pkgname) {
  # Try ladybug first (preferred name), fall back to real_ladybug (legacy name)
  ladybug_available <- reticulate::py_module_available("ladybug")
  real_ladybug_available <- reticulate::py_module_available("real_ladybug")

  pkg_name <- if (ladybug_available) {
    "ladybug"
  } else if (real_ladybug_available) {
    "real_ladybug"
  } else {
    NULL
  }

  if (!is.null(pkg_name)) {
    lbugr <<- reticulate::import(pkg_name, delay_load = TRUE)
  }
}

.onAttach <- function(libname, pkgname) {
  # Check for ladybug or real_ladybug and provide a helpful message if not found
  if (interactive()) {
    ladybug_available <- reticulate::py_module_available("ladybug")
    real_ladybug_available <- reticulate::py_module_available("real_ladybug")

    if (!ladybug_available && !real_ladybug_available) {
      msg <- paste(
        "The 'ladybug' Python package is not installed.",
        "\nPlease install it using: reticulate::py_install('ladybug', pip = TRUE)"
      )
      packageStartupMessage(msg)
    }
  }
}