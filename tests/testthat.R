# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(lbugr)

# Enforce explicit Python runtime for local/CI consistency
if (Sys.getenv("RETICULATE_PYTHON") == "") {
  stop(
    paste(
      "RETICULATE_PYTHON is not set.",
      "Set it explicitly (e.g., via project .Renviron) before running tests."
    ),
    call. = FALSE
  )
}

test_check("lbugr")
