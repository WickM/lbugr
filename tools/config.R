# Configuration helper for lbugr package
# This file is sourced during package build

# Check if Rust toolchain is available
check_rust_toolchain <- function() {
  rust_available <- system("cargo --version", ignore.stdout = TRUE, ignore.stderr = TRUE) == 0
  
  if (!rust_available) {
    stop(
      "Rust toolchain not found. Please install Rust from https://rustup.rs/\n",
      "After installation, restart your R session and try again.",
      call. = FALSE
    )
  }
  
  invisible(TRUE)
}

# Get Rust version
get_rust_version <- function() {
  tryCatch({
    version_output <- system("rustc --version", intern = TRUE)
    gsub("rustc ", "", version_output)
  }, error = function(e) {
    "unknown"
  })
}
