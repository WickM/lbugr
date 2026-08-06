# Package Initialization for lbugr

.onLoad <- function(libname, pkgname) {
  # Library loading is handled by useDynLib in NAMESPACE
  # No additional initialization needed
}

.onAttach <- function(libname, pkgname) {
  if (interactive()) {
    tryCatch({
      available <- lbug_is_available()
      if (!available) {
        packageStartupMessage(
          "lbugr: R interface to Ladybug graph database (Rust backend)\n",
          "Note: Rust backend not available. Ensure Rust and Cargo are installed."
        )
      }
    }, error = function(e) {
      # Silently ignore errors during attachment
    })
  }
}

.onUnload <- function(libpath) {
  # Library unloading is handled by useDynLib in NAMESPACE
}
