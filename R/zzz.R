# Package Initialization for lbugr

.onLoad <- function(libname, pkgname) {
  # The Rust library is loaded automatically via useDynLib in NAMESPACE
  # No additional initialization needed
}

.onAttach <- function(libname, pkgname) {
  # The Rust backend is bundled with the package, so no external dependencies
  # to check. This function is kept for potential future use.
}
