# Package Initialization for lbugr

lbugr <- NULL

.onLoad <- function(libname, pkgname) {
  # Declare Python dependency (safe, does not initialize Python)
  reticulate::py_require("ladybug")
  # Import with delay_load - Python only initializes when module is accessed
  lbugr <<- reticulate::import("ladybug", delay_load = TRUE)
}

.onAttach <- function(libname, pkgname) {
  # Only show message in interactive sessions
  # Note: py_module_available() initializes Python, so we only call it here
  # for interactive feedback, not during package load
  if (interactive()) {
    tryCatch({
      ladybug_available <- reticulate::py_module_available("ladybug")
      if (!ladybug_available) {
        packageStartupMessage(
          "The 'ladybug' Python package is not installed.\n",
          "Please install it using: reticulate::py_install('ladybug', pip = TRUE)"
        )
      }
    }, error = function(e) {
      # Silently ignore errors during attachment
    })
  }
}
