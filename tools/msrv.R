# Minimum Supported Rust Version (MSRV) for lbugr package
# This file defines the minimum Rust version required to build the package

# The MSRV is determined by the dependencies in Cargo.toml
# Current MSRV: 1.70.0 (required by extendr-api 0.9.0 and lbug 0.16.1)

MSRV <- "1.70.0"

check_msrv <- function() {
  rust_version <- tryCatch({
    version_output <- system("rustc --version", intern = TRUE)
    version_str <- gsub("rustc ([0-9.]+).*", "\\1", version_output)
    numeric_version(version_str)
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(rust_version)) {
    return(FALSE)
  }
  
  msrv <- numeric_version(MSRV)
  
  if (rust_version < msrv) {
    stop(
      "Rust version ", rust_version, " is too old.\n",
      "lbugr requires Rust >= ", MSRV, "\n",
      "Please update Rust with: rustup update",
      call. = FALSE
    )
  }
  
  invisible(TRUE)
}
