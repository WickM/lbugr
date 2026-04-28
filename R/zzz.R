# Package Initialization for lbugr

lbugr <- NULL

.onLoad <- function(libname, pkgname) {
  if (reticulate::py_module_available("ladybug")) {
    lbugr <<- reticulate::import("ladybug", delay_load = TRUE)

    # Check if this is the correct LadybugDB package (not the old CSV package v0.0.2)
    if (!"Database" %in% names(lbugr)) {
      stop(
        "The installed 'ladybug' Python package is outdated.\n",
        "You have the old CSV handling package (v0.0.2), not the LadybugDB graph database.\n",
        "\nPlease upgrade with: reticulate::py_install('ladybug', pip = TRUE)",
        call. = FALSE
      )
    }
  }
}

.onAttach <- function(libname, pkgname) {
  if (interactive()) {
    ladybug_available <- reticulate::py_module_available("ladybug")

    if (!ladybug_available) {
      msg <- paste(
        "The 'ladybug' Python package is not installed.",
        "\nPlease install it using: reticulate::py_install('ladybug', pip = TRUE)"
      )
      packageStartupMessage(msg)
    }
  }
}